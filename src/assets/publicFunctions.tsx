import type { JSX } from "react";

export function parseCurrency(amount: number): string {
  return new Intl.NumberFormat("en-KE", {
    style: "currency",
    currency: "KES",
    minimumFractionDigits: 0, // no decimals
    maximumFractionDigits: 0,
  })
    .format(amount)
    .replace("KES", "Ksh."); // Replace ISO code with "Ksh."
}

export function formatDateWithSuperscript(timestamp: any): JSX.Element {
  if (!timestamp) return <span>Unknown</span>;

  // Convert Firestore timestamp to JS Date
  const date: Date =
    typeof timestamp.toDate === "function" ? timestamp.toDate() : new Date(timestamp);

  const day = date.getDate();
  const month = date.toLocaleString("en-US", { month: "long" });
  const year = date.getFullYear();

  // Get ordinal suffix
  const suffix = (d: number) => {
    if (d > 3 && d < 21) return "th";
    switch (d % 10) {
      case 1: return "st";
      case 2: return "nd";
      case 3: return "rd";
      default: return "th";
    }
  };

  return (
    <span>
      {month} {day}
      <sup>{suffix(day)}</sup>, {year}
    </span>
  );
}

export function getGreeting(): string {
  const hour = new Date().getHours(); // 0–23

  if (hour >= 5 && hour < 12) {
    return "Good morning";
  } else if (hour >= 12 && hour < 17) {
    return "Good afternoon";
  } else if (hour >= 17 && hour < 21) {
    return "Good evening";
  } else {
    return "Good night";
  }
}

export function getDateKey(): string {
  const today = new Date();
  const months = [
    "Jan", "Feb", "Mar", "Apr", "May", "Jun",
    "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
  ];

  const day = String(today.getDate()).padStart(2, "0");
  const month = months[today.getMonth()];
  const year = today.getFullYear();

  return `${day} ${month} ${year}`;
}


export function formatElapsedTime(clockinTime: Date, now: Date): string {
  const diffMs = now.getTime() - clockinTime.getTime();

  const diffHours = Math.floor(diffMs / (1000 * 60 * 60));
  const diffMinutes = Math.floor((diffMs % (1000 * 60 * 60)) / (1000 * 60));

  return `${diffHours}h ${diffMinutes}m`;
}

// Updated toDouble function to ensure a decimal point
export const toDouble = (val: any) => {
  const num = Number(val) * 1.0;
  // This ensures the value is stored as a float in Firebase, even if it's a whole number.
  return num === Math.floor(num) ? num.toFixed(1) : num;
};

export function getWeekName(date: Date): string {
  // Align with ISO-8601 (Monday-first) week definition
  const temp = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNum = temp.getUTCDay() || 7; // Sunday → 7
  temp.setUTCDate(temp.getUTCDate() + 4 - dayNum); // move to Thursday of current week
  const yearStart = new Date(Date.UTC(temp.getUTCFullYear(), 0, 1));
  const weekNumber = Math.ceil(((temp.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);

  // Get Monday and Sunday of that ISO week
  const monday = new Date(temp);
  monday.setUTCDate(temp.getUTCDate() - (temp.getUTCDay() || 7) + 1);
  const sunday = new Date(monday);
  sunday.setUTCDate(monday.getUTCDate() + 6);

  // Custom 3-letter month formatter (force abbreviation to 3 chars)
  const format = (d: Date) => {
    const options: Intl.DateTimeFormatOptions = { day: "2-digit", month: "short", year: "numeric" };
    const parts = d.toLocaleDateString("en-GB", options).split(" ");
    if (parts.length === 3) {
      parts[1] = parts[1].substring(0, 3); // ensure exactly 3 letters
    }
    return parts.join(" ");
  };

  return `Week ${weekNumber} (${format(monday)} to ${format(sunday)})`;
}

export function getDayOfWeek(date: Date): string {
  return date.toLocaleDateString("en-US", { weekday: "long" }); 
  // e.g., "Monday"
}

