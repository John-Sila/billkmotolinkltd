// utils/formatters.ts

/**
 * Formats a number into Kenyan Shilling currency format: KSh 1,234.00
 * @param amount number to format
 * @returns formatted string
 */
export function formatCurrency(amount: number): string {
  if (isNaN(amount)) return "KSh 0.00";

  return new Intl.NumberFormat("en-KE", {
    style: "currency",
    currency: "KES",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  })
    .format(amount)
    .replace("KES", "KSh"); // Replace ISO code with KSh
}
