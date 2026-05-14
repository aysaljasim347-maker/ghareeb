import CircuitBreaker from 'opossum';

/**
 * Default options for circuit breakers.
 */
const defaultOptions: CircuitBreaker.Options = {
  timeout: 5000, // 5 seconds
  errorThresholdPercentage: 50, // 50% failure rate triggers the breaker
  resetTimeout: 30000, // Wait 30 seconds before trying again
};

/**
 * Creates a circuit breaker for a given function.
 * @param action The function to wrap.
 * @param options Overrides for default options.
 * @returns A CircuitBreaker instance.
 */
export function createBreaker<T extends (...args: any[]) => any>(
  action: T,
  options: CircuitBreaker.Options = {}
): CircuitBreaker {
  return new CircuitBreaker(action, { ...defaultOptions, ...options });
}

/**
 * Example usage for future integrations (Stripe, Cloudinary):
 * 
 * const stripeBreaker = createBreaker(stripe.confirmPayment);
 * stripeBreaker.fallback(() => ({ status: 'PENDING_RETRY', message: 'Service temporarily unavailable' }));
 */
