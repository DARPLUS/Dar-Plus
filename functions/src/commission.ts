export interface CommissionAmounts {
  grossAmount: number;
  commissionPercentage: number;
  commissionAmount: number;
  professionalNetAmount: number;
}

export function canManageCommissionSettings(role: unknown): boolean {
  return role === 'super_admin';
}

export function canCancelPayment(status: unknown): boolean {
  return status === 'en_attente';
}

export function sandboxPaymentSucceeds(cardNumber: string): boolean {
  const normalized = cardNumber.replace(/\s/g, '').toLowerCase();
  return !normalized.endsWith('0002') && !normalized.includes('fail');
}

export function roundTnd(amount: number): number {
  return Math.round((amount + Number.EPSILON) * 1000) / 1000;
}

export function validateCommissionPercentage(value: unknown): number {
  if (
    typeof value !== 'number' ||
    !Number.isFinite(value) ||
    value < 0 ||
    value > 30
  ) {
    throw new Error('Commission percentage must be between 0 and 30.');
  }
  return value;
}

export function calculateCommission(
  grossAmount: number,
  commissionPercentage: number,
  isActive: boolean,
): CommissionAmounts {
  if (!Number.isFinite(grossAmount) || grossAmount < 0) {
    throw new Error('Gross amount must be a non-negative number.');
  }
  validateCommissionPercentage(commissionPercentage);

  const commissionAmount = isActive
    ? roundTnd((grossAmount * commissionPercentage) / 100)
    : 0;
  return {
    grossAmount: roundTnd(grossAmount),
    commissionPercentage,
    commissionAmount,
    professionalNetAmount: roundTnd(grossAmount - commissionAmount),
  };
}

export interface PromotionDiscount {
  isActive: unknown;
  type: unknown;
  discount: unknown;
}

export function calculateDiscount(
  promotion: PromotionDiscount | null,
  serviceAmount: number,
): number {
  if (!promotion) return 0;
  if (!Number.isFinite(serviceAmount) || serviceAmount < 0) {
    throw new Error('Service amount must be a non-negative number.');
  }
  if (promotion.isActive !== true) {
    throw new Error('Promotion is not active.');
  }
  const discount = promotion.discount;
  if (typeof discount !== 'number' || !Number.isFinite(discount) || discount <= 0) {
    throw new Error('Promotion discount must be a positive number.');
  }

  if (promotion.type === 'percent') {
    if (discount > 100) {
      throw new Error('Percentage discount cannot exceed 100%.');
    }
    return roundTnd(Math.min(serviceAmount, (serviceAmount * discount) / 100));
  }
  if (promotion.type === 'fixed') {
    return roundTnd(Math.min(serviceAmount, discount));
  }
  throw new Error('Promotion type must be percent or fixed.');
}
