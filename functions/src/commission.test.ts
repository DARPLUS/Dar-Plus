import assert from 'node:assert/strict';
import test from 'node:test';
import {
  canCancelPayment,
  canManageCommissionSettings,
  calculateCommission,
  calculateDiscount,
  sandboxPaymentSucceeds,
  validateCommissionPercentage,
} from './commission';

test('commission at 0 percent leaves the full gross amount to the professional', () => {
  assert.deepEqual(calculateCommission(100, 0, true), {
    grossAmount: 100,
    commissionPercentage: 0,
    commissionAmount: 0,
    professionalNetAmount: 100,
  });
});

test('commission at 5 percent is rounded to millimes', () => {
  assert.deepEqual(calculateCommission(100, 5, true), {
    grossAmount: 100,
    commissionPercentage: 5,
    commissionAmount: 5,
    professionalNetAmount: 95,
  });
});

test('commission at 10 percent matches the marketplace example', () => {
  assert.deepEqual(calculateCommission(100, 10, true), {
    grossAmount: 100,
    commissionPercentage: 10,
    commissionAmount: 10,
    professionalNetAmount: 90,
  });
});

test('disabled commission is zero without changing the configured rate', () => {
  assert.deepEqual(calculateCommission(100, 10, false), {
    grossAmount: 100,
    commissionPercentage: 10,
    commissionAmount: 0,
    professionalNetAmount: 100,
  });
});

test('commission percentage rejects out-of-range and non-finite values', () => {
  for (const invalid of [-0.01, 30.01, Number.NaN, Number.POSITIVE_INFINITY]) {
    assert.throws(() => validateCommissionPercentage(invalid));
  }
});

test('active percentage and fixed promotions are calculated and capped to service price', () => {
  assert.equal(calculateDiscount({ isActive: true, type: 'percent', discount: 20 }, 100), 20);
  assert.equal(calculateDiscount({ isActive: true, type: 'fixed', discount: 5 }, 3), 3);
  assert.equal(calculateDiscount(null, 100), 0);
});

test('invalid promotion amounts and inactive promotions are rejected', () => {
  assert.throws(() => calculateDiscount({ isActive: false, type: 'percent', discount: 20 }, 100));
  assert.throws(() => calculateDiscount({ isActive: true, type: 'percent', discount: 101 }, 100));
  assert.throws(() => calculateDiscount({ isActive: true, type: 'fixed', discount: 0 }, 100));
});

test('only the Super Admin can manage commission settings', () => {
  assert.equal(canManageCommissionSettings('super_admin'), true);
  assert.equal(canManageCommissionSettings('admin'), false);
  assert.equal(canManageCommissionSettings('professionnel'), false);
  assert.equal(canManageCommissionSettings('client'), false);
});

test('sandbox card outcomes are determined on the server', () => {
  assert.equal(sandboxPaymentSucceeds('4242 4242 4242 4242'), true);
  assert.equal(sandboxPaymentSucceeds('4000000000000002'), false);
});

test('only a pending payment may be cancelled', () => {
  assert.equal(canCancelPayment('en_attente'), true);
  assert.equal(canCancelPayment('succes'), false);
  assert.equal(canCancelPayment('echec'), false);
});
