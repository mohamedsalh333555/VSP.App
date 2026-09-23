export function calculatePaymobGrossCents(
  baseAmountEgp: number,
  vspRate: number,
  gatewayRate: number,
  fixedFeeEgp: number,
): number {
  const baseCents = Math.round(baseAmountEgp * 100);
  const vspCents = Math.round(baseCents * Number(vspRate));
  const gatewayVariableCents = Math.round(baseCents * Number(gatewayRate));
  const gatewayFixedCents = Math.round(Number(fixedFeeEgp) * 100);
  return baseCents + vspCents + gatewayVariableCents + gatewayFixedCents;
}
