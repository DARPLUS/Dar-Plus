import { randomUUID } from 'node:crypto';
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import {
  FieldValue,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import {
  HttpsError,
  onCall,
} from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import {
  canCancelPayment,
  canManageCommissionSettings,
  calculateCommission,
  calculateDiscount,
  PromotionDiscount,
  roundTnd,
  sandboxPaymentSucceeds,
  validateCommissionPercentage,
} from './commission';

initializeApp();

const db = getFirestore();
const auth = getAuth();
const defaultCommissionSettings = {
  commissionPercentage: 10,
  isActive: true,
};
const callableOptions = {
  enforceAppCheck: process.env.FUNCTIONS_EMULATOR !== 'true',
};

function escapeEmailHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character] ?? character);
}

function buildAuthEmailHtml(
  type: 'passwordReset' | 'emailVerification',
  email: string,
  name: string,
  actionLink: string,
  languageCode: 'fr' | 'en' | 'ar',
): { subject: string; html: string } {
  const copy = {
    fr: {
      resetSubject: 'Réinitialisation de votre mot de passe DAR PLUS',
      verifySubject: 'Vérifiez votre adresse e-mail DAR PLUS',
      resetTitle: 'Réinitialiser mon mot de passe',
      verifyTitle: 'Vérifier mon adresse e-mail',
      resetText: 'Cliquez sur le bouton pour choisir un nouveau mot de passe.',
      verifyText: 'Confirmez votre adresse e-mail pour activer votre compte client.',
      ignore: 'Si vous n’êtes pas à l’origine de cette demande, ignorez cet e-mail.',
      fallback: 'Si le bouton ne fonctionne pas, ouvrez ce lien :',
      greeting: 'Bonjour',
    },
    en: {
      resetSubject: 'Reset your DAR PLUS password',
      verifySubject: 'Verify your DAR PLUS email address',
      resetTitle: 'Reset my password',
      verifyTitle: 'Verify my email address',
      resetText: 'Click the button to choose a new password.',
      verifyText: 'Verify your email address to activate your client account.',
      ignore: 'If you did not request this, you can ignore this email.',
      fallback: 'If the button does not work, open this link:',
      greeting: 'Hello',
    },
    ar: {
      resetSubject: 'إعادة تعيين كلمة مرور دار بلس',
      verifySubject: 'تحقق من بريدك الإلكتروني في دار بلس',
      resetTitle: 'إعادة تعيين كلمة المرور',
      verifyTitle: 'تحقق من البريد الإلكتروني',
      resetText: 'اضغط على الزر لاختيار كلمة مرور جديدة.',
      verifyText: 'تحقق من بريدك الإلكتروني لتفعيل حساب العميل.',
      ignore: 'إذا لم تطلب هذا الإجراء، فتجاهل هذه الرسالة.',
      fallback: 'إذا لم يعمل الزر، افتح هذا الرابط:',
      greeting: 'مرحباً',
    },
  }[languageCode];
  const isReset = type === 'passwordReset';
  const title = isReset ? copy.resetTitle : copy.verifyTitle;
  const action = escapeEmailHtml(actionLink);
  const safeName = escapeEmailHtml(name);
  const safeEmail = escapeEmailHtml(email);
  return {
    subject: isReset ? copy.resetSubject : copy.verifySubject,
    html: `<!doctype html><html lang="${languageCode}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><style>body{margin:0;background:#f4f4f4;font-family:Arial,sans-serif;color:#334155}.card{max-width:560px;margin:32px auto;background:#fff;border-radius:16px;overflow:hidden}.header{background:#0D544E;color:#fff;padding:28px;text-align:center;font-size:24px;font-weight:bold}.body{padding:32px;line-height:1.6}.button{display:inline-block;background:#0D544E;color:#fff!important;text-decoration:none;padding:14px 28px;border-radius:8px;font-weight:bold}.fallback{font-size:12px;word-break:break-all;color:#64748b}</style></head><body><div class="card"><div class="header">DAR PLUS</div><div class="body"><p>${copy.greeting} ${safeName},</p><p>${isReset ? copy.resetText : copy.verifyText} <strong>${safeEmail}</strong></p><p style="text-align:center;margin:28px 0"><a class="button" href="${action}">${title}</a></p><p>${copy.fallback}</p><p class="fallback"><a href="${action}">${action}</a></p><p>${copy.ignore}</p></div></div></body></html>`,
  };
}

export const sendFirebaseAuthEmail = onCall(
  callableOptions,
  async (request) => {
    const type = request.data?.type;
    const email = typeof request.data?.email === 'string'
      ? request.data.email.trim().toLowerCase()
      : '';
    if (!['passwordReset', 'emailVerification'].includes(type)) {
      throw new HttpsError('invalid-argument', 'Type d’e-mail invalide.');
    }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      throw new HttpsError('invalid-argument', 'Adresse e-mail invalide.');
    }

    const languageCode = ['fr', 'en', 'ar'].includes(request.data?.languageCode)
      ? request.data.languageCode
      : 'fr';
    const emailJs = request.data?.emailJs;
    if (
      typeof emailJs?.serviceId !== 'string' ||
      typeof emailJs?.templateId !== 'string' ||
      typeof emailJs?.publicKey !== 'string' ||
      !emailJs.serviceId.trim() ||
      !emailJs.templateId.trim() ||
      !emailJs.publicKey.trim()
    ) {
      throw new HttpsError('failed-precondition', 'La configuration EmailJS est incomplète.');
    }
    let actionLink: string;
    if (type === 'emailVerification') {
      const uid = requireAuthenticatedUid(request.auth?.uid);
      const user = await auth.getUser(uid);
      if (user.email?.toLowerCase() !== email) {
        throw new HttpsError('permission-denied', 'Adresse e-mail non autorisée.');
      }
      if (user.emailVerified) return { sent: true, alreadyVerified: true };
      actionLink = await auth.generateEmailVerificationLink(email);
    } else {
      try {
        actionLink = await auth.generatePasswordResetLink(email);
      } catch (error) {
        const code = (error as { code?: string }).code;
        if (code === 'auth/user-not-found') {
          // Keep reset requests indistinguishable for existing and unknown emails.
          return { sent: true };
        }
        throw new HttpsError('internal', 'Impossible de préparer le lien de réinitialisation.');
      }
    }

    const recipientName = typeof request.data?.userName === 'string'
      ? request.data.userName.trim().slice(0, 100)
      : email.split('@')[0];
    const mail = buildAuthEmailHtml(type, email, recipientName, actionLink, languageCode);
    let response: Response;
    try {
      response = await fetch('https://api.emailjs.com/api/v1.0/email/send', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          service_id: emailJs.serviceId,
          template_id: emailJs.templateId,
          user_id: emailJs.publicKey,
          template_params: {
            to_email: email,
            to_name: recipientName,
            from_name: 'DAR PLUS',
            name: 'DAR PLUS',
            subject: mail.subject,
            html_body: mail.html,
          },
        }),
        signal: AbortSignal.timeout(20000),
      });
    } catch {
      throw new HttpsError('unavailable', 'EmailJS est temporairement indisponible.');
    }
    if (!response.ok) {
      throw new HttpsError('internal', 'EmailJS a refusé l’envoi de l’e-mail.');
    }
    return { sent: true };
  },
);

function requireAuthenticatedUid(uid: string | undefined): string {
  if (!uid) {
    throw new HttpsError('unauthenticated', 'Connexion requise.');
  }
  return uid;
}

async function requireSuperAdmin(uid: string): Promise<void> {
  const user = await db.collection('users').doc(uid).get();
  if (!canManageCommissionSettings(user.data()?.role)) {
    throw new HttpsError(
      'permission-denied',
      'Cette action est réservée au Super Admin.',
    );
  }
}

function parseBookingAmount(value: unknown): number {
  if (typeof value === 'number' && Number.isFinite(value) && value > 0) {
    return roundTnd(value);
  }
  if (typeof value === 'string') {
    const match = /(\d+(?:[.,]\d+)?)/.exec(value);
    const amount = match
      ? Number.parseFloat(match[1].replace(',', '.'))
      : Number.NaN;
    if (Number.isFinite(amount) && amount > 0) return roundTnd(amount);
  }
  throw new HttpsError(
    'failed-precondition',
    'Le tarif de cette réservation est indisponible.',
  );
}

function requireRequestId(value: unknown): string {
  if (
    typeof value !== 'string' ||
    !/^[a-zA-Z0-9_-]{8,100}$/.test(value)
  ) {
    throw new HttpsError('invalid-argument', 'Identifiant de paiement invalide.');
  }
  return value;
}

export const getCommissionSettings = onCall(
  callableOptions,
  async (request) => {
    requireAuthenticatedUid(request.auth?.uid);
    const settingsRef = db.collection('platform_settings').doc('commission');
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(settingsRef);
      if (!current.exists) {
        transaction.create(settingsRef, {
          ...defaultCommissionSettings,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: 'system',
        });
      }
    });
    const snapshot = await settingsRef.get();
    return snapshot.data() ?? defaultCommissionSettings;
  },
);

export const updateCommissionSettings = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    await requireSuperAdmin(uid);

    const percentage = validateCommissionPercentage(
      request.data?.commissionPercentage,
    );
    if (typeof request.data?.isActive !== 'boolean') {
      throw new HttpsError(
        'invalid-argument',
        'L’état de la commission doit être activé ou désactivé.',
      );
    }

    await db.collection('platform_settings').doc('commission').set(
      {
        commissionPercentage: percentage,
        isActive: request.data.isActive,
        updatedAt: FieldValue.serverTimestamp(),
        updatedBy: uid,
      },
      { merge: true },
    );
    return { success: true };
  },
);

export const createPaymentSession = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    const bookingId =
      typeof request.data?.bookingId === 'string'
        ? request.data.bookingId
        : '';
    const requestId = requireRequestId(request.data?.requestId);
    const paymentMethod = request.data?.paymentMethod;
    if (!bookingId || !['carte_bancaire', 'konnect'].includes(paymentMethod)) {
      throw new HttpsError('invalid-argument', 'Données de paiement invalides.');
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const requestRef = db
      .collection('_paymentRequests')
      .doc(`${uid}_checkout_${requestId}`);
    const paymentRef = db
      .collection('payments')
      .doc(`pay_sb_${randomUUID()}`);
    const result = await db.runTransaction(async (transaction) => {
      const requestSnapshot = await transaction.get(requestRef);
      if (requestSnapshot.exists) {
        return { paymentId: requestSnapshot.data()?.paymentId as string };
      }

      const bookingSnapshot = await transaction.get(bookingRef);
      const userSnapshot = await transaction.get(
        db.collection('users').doc(uid),
      );
      if (!bookingSnapshot.exists || !userSnapshot.exists) {
        throw new HttpsError('not-found', 'Réservation ou client introuvable.');
      }
      const booking = bookingSnapshot.data()!;
      if (userSnapshot.data()?.role !== 'client') {
        throw new HttpsError(
          'permission-denied',
          'Seul un client peut régler une réservation.',
        );
      }
      if (
        booking.clientId !== uid ||
        booking.status !== 'confirmee' ||
        booking.paymentStatus === 'paye'
      ) {
        throw new HttpsError(
          'failed-precondition',
          'Cette réservation ne peut pas être payée.',
        );
      }

      const grossAmount = parseBookingAmount(
        booking.baseAmount ?? booking.price,
      );
      const settings = await transaction.get(
        db.collection('platform_settings').doc('commission'),
      );
      const percentage = validateCommissionPercentage(
        settings.data()?.commissionPercentage ?? 10,
      );
      const paymentId = paymentRef.id;
      const now = Timestamp.now();
      transaction.create(paymentRef, {
        id: paymentId,
        bookingId,
        clientId: uid,
        clientName: String(userSnapshot.data()?.fullName ?? 'Client'),
        clientEmail: String(request.auth?.token.email ?? ''),
        proId: String(booking.proId ?? ''),
        proName: String(booking.proName ?? 'Professionnel'),
        serviceType: String(booking.serviceType ?? 'Service'),
        baseAmount: grossAmount,
        grossAmount,
        feeAmount: 2.5,
        discountAmount: 0,
        totalAmount: roundTnd(grossAmount + 2.5),
        commissionPercentage: percentage,
        commissionAmount: 0,
        professionalNetAmount: 0,
        currency: 'TND',
        status: 'en_attente',
        paymentStatus: 'pending',
        paymentMethod,
        paymentProvider: 'sandbox',
        transactionRef: `PENDING-${randomUUID()}`,
        isSandbox: true,
        createdAt: now,
        updatedAt: now,
      });
      transaction.create(requestRef, { paymentId });
      return { paymentId };
    });
    return result;
  },
);

export const processSandboxPayment = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    const bookingId =
      typeof request.data?.bookingId === 'string'
        ? request.data.bookingId
        : '';
    const gateway = request.data?.gateway;
    const paymentMethod = request.data?.paymentMethod;
    const isSubscription = request.data?.isSubscription === true;
    const requestId = requireRequestId(request.data?.requestId);
    const testCardNumber =
      typeof request.data?.testCardNumber === 'string'
        ? request.data.testCardNumber.replace(/\s/g, '')
        : '';

    if (!['stripe_test', 'konnect_sandbox'].includes(gateway)) {
      throw new HttpsError(
        'failed-precondition',
        'Seuls les moyens de paiement en ligne de test sont disponibles.',
      );
    }
    if (!['carte_bancaire', 'konnect'].includes(paymentMethod)) {
      throw new HttpsError(
        'invalid-argument',
        'Moyen de paiement en ligne invalide.',
      );
    }
    if (!isSubscription && !bookingId) {
      throw new HttpsError('invalid-argument', 'Réservation manquante.');
    }

    const bookingRef = bookingId
      ? db.collection('bookings').doc(bookingId)
      : null;
    const userRef = db.collection('users').doc(uid);
    const settingsRef = db.collection('platform_settings').doc('commission');
    const paymentRef = db
      .collection('payments')
      .doc(`pay_sb_${randomUUID()}`);
    const commissionRef = db
      .collection('platform_commissions')
      .doc(paymentRef.id);
    const professionalNotificationRef = db.collection('notifications').doc();
    const requestRef = db
      .collection('_paymentRequests')
      .doc(`${uid}_${requestId}`);
    const adminsSnapshot = await db
      .collection('users')
      .where('role', 'in', ['admin', 'super_admin'])
      .limit(450)
      .get();
    const adminNotificationRefs = adminsSnapshot.docs.map((admin) =>
      db.collection('notifications').doc(),
    );

    const result = await db.runTransaction(async (transaction) => {
      const idempotency = await transaction.get(requestRef);
      if (idempotency.exists) {
        return { paymentId: idempotency.data()?.paymentId as string };
      }

      const userSnapshot = await transaction.get(userRef);
      if (!userSnapshot.exists) {
        throw new HttpsError(
          'failed-precondition',
          'Profil client introuvable.',
        );
      }
      if (userSnapshot.data()?.role !== 'client') {
        throw new HttpsError(
          'permission-denied',
          'Seul un client peut effectuer un paiement.',
        );
      }

      const [bookingSnapshot, settingsSnapshot] = await Promise.all([
        bookingRef ? transaction.get(bookingRef) : Promise.resolve(null),
        transaction.get(settingsRef),
      ]);

      let serviceName = 'Abonnement DAR+ Sérénité';
      let professionalId = '';
      let professionalName = 'DAR PLUS';
      let listedServiceAmount = 29.9;
      if (!isSubscription) {
        if (!bookingSnapshot?.exists) {
          throw new HttpsError('not-found', 'Réservation introuvable.');
        }
        const booking = bookingSnapshot.data()!;
        if (booking.clientId !== uid) {
          throw new HttpsError(
            'permission-denied',
            'Cette réservation ne vous appartient pas.',
          );
        }
        if (booking.status !== 'confirmee') {
          throw new HttpsError(
            'failed-precondition',
            'Le professionnel doit accepter la réservation avant le paiement.',
          );
        }
        if (booking.paymentStatus === 'paye') {
          throw new HttpsError(
            'already-exists',
            'Cette réservation est déjà payée.',
          );
        }
        professionalId = String(booking.proId ?? '');
        professionalName = String(booking.proName ?? 'Professionnel');
        serviceName = String(booking.serviceType ?? 'Service');
        listedServiceAmount = parseBookingAmount(
          booking.baseAmount ?? booking.price,
        );
        const professional = await transaction.get(
          db.collection('users').doc(professionalId),
        );
        if (
          !professional.exists ||
          professional.data()?.role !== 'professionnel' ||
          professional.data()?.isApproved !== true
        ) {
          throw new HttpsError(
            'failed-precondition',
            'Le professionnel de cette réservation est invalide.',
          );
        }
      }

      const settings = settingsSnapshot.data() ?? defaultCommissionSettings;
      const percentage = validateCommissionPercentage(
        settings.commissionPercentage ?? 10,
      );
      const commissionActive = settings.isActive !== false;
      const promoCode = typeof request.data?.promoCode === 'string'
        ? request.data.promoCode.trim().toUpperCase()
        : '';
      let discountAmount = 0;
      if (promoCode && !isSubscription) {
        const promotionSnapshot = await transaction.get(
          db.collection('promotions').where('code', '==', promoCode).limit(1),
        );
        const promotion = promotionSnapshot.docs[0]?.data();
        if (!promotion || promotion.isActive !== true) {
          throw new HttpsError('failed-precondition', 'Ce code promo est invalide ou expiré.');
        }
        try {
          discountAmount = calculateDiscount(promotion as PromotionDiscount, listedServiceAmount);
        } catch (error) {
          throw new HttpsError('failed-precondition', 'La promotion configurée est invalide.');
        }
      } else if (promoCode && isSubscription) {
        throw new HttpsError('failed-precondition', 'Les codes promo ne sont pas disponibles pour cet abonnement.');
      }
      const grossAmount = roundTnd(
        Math.max(0, listedServiceAmount - discountAmount),
      );
      const feeAmount = isSubscription ? 0 : 2.5;
      const totalAmount = roundTnd(grossAmount + feeAmount);
      const commission = isSubscription
        ? {
            grossAmount,
            commissionPercentage: percentage,
            commissionAmount: 0,
            professionalNetAmount: 0,
          }
        : calculateCommission(grossAmount, percentage, commissionActive);

      const failed = !sandboxPaymentSucceeds(testCardNumber);
      const status = failed ? 'echec' : 'succes';
      const paymentStatus = failed ? 'failed' : 'confirmed';
      const failureReason = failed
        ? 'Carte de test refusée par la passerelle Sandbox.'
        : null;
      const transactionReference = `SANDBOX-${randomUUID()}`;
      const now = Timestamp.now();
      const paymentData = {
        id: paymentRef.id,
        bookingId: bookingId || '',
        clientId: uid,
        clientName: String(userSnapshot.data()?.fullName ?? 'Client'),
        clientEmail: String(request.auth?.token.email ?? ''),
        proId: professionalId,
        proName: professionalName,
        serviceType: serviceName,
        baseAmount: listedServiceAmount,
        grossAmount,
        feeAmount,
        discountAmount,
        ...(promoCode ? { promoCode } : {}),
        totalAmount,
        commissionPercentage: percentage,
        commissionAmount: failed ? 0 : commission.commissionAmount,
        professionalNetAmount: failed
          ? 0
          : commission.professionalNetAmount,
        currency: 'TND',
        status,
        paymentStatus,
        paymentMethod,
        paymentProvider: gateway,
        gateway,
        transactionRef: transactionReference,
        transactionReference,
        failureReason,
        isSandbox: true,
        isSubscription,
        createdAt: now,
        updatedAt: now,
        ...(failed ? {} : { confirmedAt: now }),
      };

      transaction.create(paymentRef, paymentData);
      transaction.create(requestRef, { paymentId: paymentRef.id });
      if (!failed && !isSubscription && bookingRef) {
        transaction.update(bookingRef, {
          paymentStatus: 'paye',
          paymentId: paymentRef.id,
          paidAmount: totalAmount,
          commissionPercentage: percentage,
          commissionAmount: commission.commissionAmount,
          professionalNetAmount: commission.professionalNetAmount,
          paidAt: FieldValue.serverTimestamp(),
        });
        transaction.create(commissionRef, {
          paymentId: paymentRef.id,
          bookingId,
          professionalId,
          grossAmount,
          commissionPercentage: percentage,
          commissionAmount: commission.commissionAmount,
          professionalNetAmount: commission.professionalNetAmount,
          currency: 'TND',
          status: 'confirmed',
          isSandbox: true,
          createdAt: now,
        });
        if (professionalId) {
          transaction.create(professionalNotificationRef, {
            recipientId: professionalId,
            type: 'payment_received',
            title: 'Paiement reçu',
            body: `${String(userSnapshot.data()?.fullName ?? 'Un client')} a payé ${totalAmount.toFixed(3)} TND pour ${serviceName}.`,
            paymentId: paymentRef.id,
            bookingId,
            clientName: String(userSnapshot.data()?.fullName ?? 'Un client'),
            serviceType: serviceName,
            totalAmount,
            paymentMethod,
            isRead: false,
            createdAt: now,
          });
        }
      }

      if (!failed && isSubscription) {
        transaction.set(
          userRef,
          {
            subscription: 'dar_plus_serenite',
            subscriptionStatus: 'active',
            subscribedAt: FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      }

      if (!failed) {
        adminsSnapshot.docs.forEach((admin, index) => {
          const commissionText = isSubscription
            ? 'Aucune commission (abonnement).'
            : `Commission DAR PLUS : ${percentage.toFixed(2)} % (${commission.commissionAmount.toFixed(3)} TND).`;
          const netText = isSubscription
            ? ''
            : `Net professionnel : ${commission.professionalNetAmount.toFixed(3)} TND.`;
          transaction.create(adminNotificationRefs[index], {
            recipientId: admin.id,
            type: 'payment_confirmed',
            title: 'Paiement Sandbox confirmé',
            body: `SANDBOX · Client : ${String(userSnapshot.data()?.fullName ?? 'Client')} · Professionnel : ${professionalName} · ${serviceName} · Prestation : ${grossAmount.toFixed(3)} TND · ${commissionText} ${netText} Total payé : ${totalAmount.toFixed(3)} TND.`,
            paymentId: paymentRef.id,
            bookingId: bookingId || null,
            clientName: String(userSnapshot.data()?.fullName ?? 'Client'),
            proName: professionalName,
            serviceType: serviceName,
            grossAmount,
            discountAmount,
            feeAmount,
            totalAmount,
            commissionPercentage: percentage,
            commissionAmount: isSubscription ? 0 : commission.commissionAmount,
            professionalNetAmount: commission.professionalNetAmount,
            paymentMethod,
            paymentProvider: gateway,
            transactionReference,
            isSandbox: true,
            isRead: false,
            createdAt: now,
          });
        });
      }

      return { paymentId: paymentRef.id };
    });

    logger.info('Sandbox payment processed', {
      paymentId: result.paymentId,
      uid,
      bookingId,
    });
    return result;
  },
);

export const cancelSandboxPayment = onCall(
  callableOptions,
  async (request) => {
    const uid = requireAuthenticatedUid(request.auth?.uid);
    const paymentId =
      typeof request.data?.paymentId === 'string'
        ? request.data.paymentId
        : '';
    if (!paymentId) {
      throw new HttpsError('invalid-argument', 'Paiement manquant.');
    }

    const paymentRef = db.collection('payments').doc(paymentId);
    await db.runTransaction(async (transaction) => {
      const payment = await transaction.get(paymentRef);
      if (!payment.exists || payment.data()?.clientId !== uid) {
        throw new HttpsError('not-found', 'Paiement introuvable.');
      }
      if (!canCancelPayment(payment.data()?.status)) {
        throw new HttpsError(
          'failed-precondition',
          'Ce paiement ne peut plus être annulé.',
        );
      }
      transaction.update(paymentRef, {
        status: 'annule',
        paymentStatus: 'cancelled',
        failureReason: 'Annulé par le client.',
        updatedAt: FieldValue.serverTimestamp(),
      });
    });
    return { success: true };
  },
);


// Notification push lors d'un nouveau message de chat.
export const onChatMessageCreated = onDocumentCreated(
  'bookings/{bookingId}/messages/{messageId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const senderId = data.senderId as string | undefined;
    const text = (data.text as string | undefined) ?? '';
    if (!senderId) return;

    const bookingSnap = await db.collection('bookings').doc(event.params.bookingId).get();
    const booking = bookingSnap.data();
    if (!booking) return;
    const clientId = booking.clientId as string | undefined;
    const proId = booking.proId as string | undefined;
    const clientName = (booking.clientName as string) ?? 'Client';
    const proName = (booking.proName as string) ?? 'Professionnel';

    const recipientId = senderId === clientId ? proId : clientId;
    if (!recipientId || recipientId === senderId) return;

    const recipientSnap = await db.collection('users').doc(recipientId).get();
    const token = recipientSnap.data()?.fcmToken as string | undefined;
    if (!token) return;

    const senderName = senderId === clientId ? clientName : proName;
    await getMessaging().send({
      token,
      notification: {
        title: `Nouveau message de ${senderName}`,
        body: text.length > 120 ? text.slice(0, 117) + '...' : text,
      },
      data: {
        type: 'chat',
        bookingId: event.params.bookingId,
      },
    });
  },
);

// Notification push lors d'une nouvelle reservation (au professionnel).
export const onBookingCreated = onDocumentCreated(
  'bookings/{bookingId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const proId = data.proId as string | undefined;
    const clientName = (data.clientName as string) ?? 'Un client';
    const serviceType = (data.serviceType as string) ?? 'un service';
    if (!proId) return;

    const proSnap = await db.collection('users').doc(proId).get();
    const token = proSnap.data()?.fcmToken as string | undefined;
    if (!token) return;

    await getMessaging().send({
      token,
      notification: {
        title: 'Nouvelle demande de reservation',
        body: `${clientName} a demande ${serviceType}.`,
      },
      data: {
        type: 'booking',
        bookingId: event.params.bookingId,
      },
    });
  },
);

// Notification push haute priorite pour un appel entrant (reveille l'application).
export const onCallCreated = onDocumentCreated(
  'calls/{callId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    if (data.status !== 'ringing') return;
    const calleeId = data.calleeId as string | undefined;
    const callerName = (data.callerName as string) ?? 'Un contact';
    const serviceType = (data.serviceType as string) ?? '';
    if (!calleeId) return;

    const calleeSnap = await db.collection('users').doc(calleeId).get();
    const token = calleeSnap.data()?.fcmToken as string | undefined;
    if (!token) return;

    await getMessaging().send({
      token,
      data: {
        type: 'incoming_call',
        callId: event.params.callId,
        callerName,
        serviceType,
      },
      android: {
        priority: 'high',
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: { aps: { 'content-available': 1 } },
      },
    });
  },
);

// Notification push lors d'un nouveau paiement (a l'admin).
export const onPaymentCreated = onDocumentCreated(
  'payments/{paymentId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const gross = data.grossAmount ?? data.amount ?? 0;
    const clientName = (data.clientName as string) ?? 'Un client';

    // Notifier le professionnel concerné par la prestation payée.
    const professionalId = data.proId as string | undefined;
    if (professionalId && !data.isSubscription) {
      const professionalSnap = await db.collection('users').doc(professionalId).get();
      const professionalToken = professionalSnap.data()?.fcmToken as string | undefined;
      if (professionalToken) {
        await getMessaging().send({
          token: professionalToken,
          notification: {
            title: 'Paiement reçu',
            body: `${clientName} a payé ${gross} TND pour ${String(data.serviceType ?? 'votre prestation')}.`,
          },
          data: {
            type: 'payment_received',
            paymentId: event.params.paymentId,
            bookingId: String(data.bookingId ?? ''),
          },
        });
      }
    }

    // Notifier tous les admins.
    const admins = await db.collection('users').where('role', 'in', ['admin', 'super_admin']).get();
    const tokens: string[] = [];
    admins.forEach((d) => {
      const t = d.data()?.fcmToken as string | undefined;
      if (t) tokens.push(t);
    });
    if (tokens.length === 0) return;

    await getMessaging().sendEachForMulticast({
      tokens,
      notification: {
        title: 'Nouveau paiement en ligne',
        body: `${clientName} a paye ${gross} TND.`,
      },
      data: {
        type: 'payment',
        paymentId: event.params.paymentId,
      },
    });
  },
);

export const onReviewCreated = onDocumentCreated(
  'reviews/{reviewId}',
  async (event) => {
    const review = event.data?.data();
    if (!review) return;
    const targetId = review.targetId as string | undefined;
    if (!targetId) return;
    const target = await db.collection('users').doc(targetId).get();
    const token = target.data()?.fcmToken as string | undefined;
    if (!token) return;
    await getMessaging().send({
      token,
      notification: {
        title: 'Nouvel avis reçu',
        body: `${String(review.reviewerName ?? 'Un utilisateur')} vous a attribué ${Number(review.rating)}/5${review.serviceType ? ` pour ${String(review.serviceType)}` : ''}.`,
      },
      data: {
        type: 'booking_review_received',
        bookingId: String(review.bookingId ?? ''),
        rating: String(review.rating ?? ''),
      },
    });
  },
);

export const submitBookingRating = onCall(callableOptions, async (request) => {
  const uid = requireAuthenticatedUid(request.auth?.uid);
  const bookingId = typeof request.data?.bookingId === 'string' ? request.data.bookingId : '';
  const rating = request.data?.rating;
  const comment = typeof request.data?.comment === 'string' ? request.data.comment.trim() : '';
  if (!bookingId || !Number.isInteger(rating) || rating < 1 || rating > 5 || comment.length > 500) {
    throw new HttpsError('invalid-argument', 'Note ou commentaire invalide.');
  }

  const bookingRef = db.collection('bookings').doc(bookingId);
  const result = await db.runTransaction(async (transaction) => {
    const bookingSnapshot = await transaction.get(bookingRef);
    const authorRef = db.collection('users').doc(uid);
    const authorSnapshot = await transaction.get(authorRef);
    if (!bookingSnapshot.exists || !authorSnapshot.exists) {
      throw new HttpsError('not-found', 'Réservation ou profil introuvable.');
    }
    const booking = bookingSnapshot.data()!;
    if (booking.status !== 'terminee') {
      throw new HttpsError('failed-precondition', 'La réservation doit être terminée.');
    }
    const reviewerRole = booking.clientId === uid ? 'client' : booking.proId === uid ? 'professionnel' : null;
    if (!reviewerRole || authorSnapshot.data()?.role !== reviewerRole) {
      throw new HttpsError('permission-denied', 'Vous ne participez pas à cette réservation.');
    }
    const targetId = reviewerRole === 'client' ? booking.proId : booking.clientId;
    const targetRole = reviewerRole === 'client' ? 'professionnel' : 'client';
    const reviewRef = db.collection('reviews').doc(`${bookingId}_${reviewerRole}`);
    const reviewSnapshot = await transaction.get(reviewRef);
    if (reviewSnapshot.exists || booking[`${reviewerRole === 'client' ? 'client' : 'pro'}ReviewSubmitted`] === true) {
      throw new HttpsError('already-exists', 'Vous avez déjà évalué cette réservation.');
    }
    const targetRef = db.collection('users').doc(targetId);
    const targetSnapshot = await transaction.get(targetRef);
    if (!targetSnapshot.exists) throw new HttpsError('not-found', 'Profil à évaluer introuvable.');
    const existingReviews = await transaction.get(db.collection('reviews').where('targetId', '==', targetId));
    const legacyProReviews = targetRole === 'professionnel'
      ? await transaction.get(db.collection('reviews').where('proId', '==', targetId))
      : null;
    const reviewDocs = new Map(existingReviews.docs.map((doc) => [doc.id, doc]));
    legacyProReviews?.docs.forEach((doc) => reviewDocs.set(doc.id, doc));
    const previousRatings = [...reviewDocs.values()].map((doc) => Number(doc.data().rating)).filter((value) => Number.isFinite(value));
    const ratingSum = previousRatings.reduce((sum, value) => sum + value, 0) + rating;
    const reviewsCount = previousRatings.length + 1;
    const author = authorSnapshot.data()!;
    transaction.create(reviewRef, {
      bookingId,
      reviewerId: uid,
      reviewerName: author.fullName ?? 'Utilisateur',
      reviewerRole,
      targetId,
      targetRole,
      proId: booking.proId,
      rating,
      comment,
      serviceType: booking.serviceType ?? '',
      createdAt: FieldValue.serverTimestamp(),
    });
    transaction.update(bookingRef, {
      [`${reviewerRole === 'client' ? 'client' : 'pro'}ReviewSubmitted`]: true,
      [`${reviewerRole === 'client' ? 'client' : 'pro'}Rating`]: rating,
    });
    transaction.update(targetRef, {
      ratingSum,
      rating: Math.round((ratingSum / reviewsCount) * 10) / 10,
      reviewsCount,
    });
    return { rating: Math.round((ratingSum / reviewsCount) * 10) / 10, reviewsCount };
  });
  return { success: true, ...result };
});

export const getBookingClientPhoto = onCall(callableOptions, async (request) => {
  const uid = requireAuthenticatedUid(request.auth?.uid);
  const bookingId = typeof request.data?.bookingId === 'string' ? request.data.bookingId : '';
  if (!bookingId) throw new HttpsError('invalid-argument', 'Réservation invalide.');
  const bookingSnapshot = await db.collection('bookings').doc(bookingId).get();
  if (!bookingSnapshot.exists) throw new HttpsError('not-found', 'Réservation introuvable.');
  const booking = bookingSnapshot.data()!;
  if (booking.proId !== uid) {
    throw new HttpsError('permission-denied', 'Seul le professionnel de cette réservation peut voir le profil du client.');
  }
  const clientId = typeof booking.clientId === 'string' ? booking.clientId : '';
  if (!clientId) return { photoBase64: '', photoUrl: '' };
  const clientSnapshot = await db.collection('users').doc(clientId).get();
  if (!clientSnapshot.exists) return { photoBase64: '', photoUrl: '' };
  const client = clientSnapshot.data()!;
  return {
    photoBase64: typeof client.photoBase64 === 'string' ? client.photoBase64 : '',
    photoUrl: typeof client.photoUrl === 'string' ? client.photoUrl : '',
  };
});
