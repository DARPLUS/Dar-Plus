'use strict';

const { randomBytes } = require('node:crypto');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || '';
if (
  !projectId.startsWith('demo-') ||
  !process.env.FIREBASE_AUTH_EMULATOR_HOST ||
  !process.env.FIRESTORE_EMULATOR_HOST
) {
  throw new Error(
    'Seed data only in the demo project with Auth and Firestore emulators running.',
  );
}

const app = initializeApp({ projectId });
const auth = getAuth(app);
const db = getFirestore(app);

function createPassword() {
  return `${randomBytes(18).toString('base64url')}A9!`;
}

async function ensureUser(email, fullName, profile) {
  const password = createPassword();
  let user;
  try {
    const existing = await auth.getUserByEmail(email);
    user = await auth.updateUser(existing.uid, {
      displayName: fullName,
      password,
      disabled: false,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    user = await auth.createUser({ email, password, displayName: fullName });
  }

  await db.collection('users').doc(user.uid).set(
    {
      uid: user.uid,
      email,
      fullName,
      phone: '',
      isActive: true,
      createdAt: Timestamp.now(),
      ...profile,
    },
    { merge: true },
  );
  return { uid: user.uid, email, password };
}

async function seed() {
  const client = await ensureUser('client@local.test', 'Client Test', {
    role: 'client',
    isApproved: true,
  });
  const professional = await ensureUser(
    'pro@local.test',
    'Professionnel Test',
    {
      role: 'professionnel',
      serviceType: 'Peinture',
      isApproved: true,
      status: 'valide',
      available: true,
      price: '100 TND',
      priceValue: 100,
      rating: 5,
      reviewsCount: 0,
      location: 'Tunis, El Menzah',
      distance: 1,
      bio: 'Compte de test local.',
    },
  );
  const admin = await ensureUser('admin@local.test', 'Admin Test', {
    role: 'super_admin',
    isApproved: true,
  });

  const now = Timestamp.now();
  await db.collection('platform_settings').doc('commission').set(
    {
      commissionPercentage: 10,
      isActive: true,
      updatedAt: now,
      updatedBy: admin.uid,
    },
    { merge: true },
  );
  await db.collection('bookings').doc('demo-payment-booking').set({
    id: 'demo-payment-booking',
    clientId: client.uid,
    clientName: 'Client Test',
    clientEmail: client.email,
    clientPhone: '',
    proId: professional.uid,
    proName: 'Professionnel Test',
    proPhone: '',
    serviceType: 'Peinture',
    baseAmount: 100,
    price: '100 TND',
    address: 'Adresse de test locale',
      description: 'Réservation locale pour tester le parcours Peinture.',
    scheduledDate: 'Dès que possible',
    status: 'confirmee',
    paymentStatus: 'en_attente',
    createdAt: now,
    acceptedAt: now,
  });

  console.log(
    JSON.stringify(
      {
        projectId,
        bookingId: 'demo-payment-booking',
        client,
        professional,
        admin,
      },
      null,
      2,
    ),
  );
}

seed()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => app.delete());
