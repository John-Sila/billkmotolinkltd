import { doc, getDoc, Timestamp } from "firebase/firestore";
import { db } from "../assets/Firebase";

export interface UserData {
  clockInTime?: Timestamp;
  clockinMileage?: number;
  createdAt?: Timestamp;
  currentBike?: string;
  currentInAppBalance?: number;
  dailyTarget?: number;
  dtbAccNo?: string;
  email?: string;
  fcmToken?: string;
  gender?: string;
  hrsPerShift?: number;
  idNumber?: string;
  isActive?: boolean;
  isCharging?: boolean;
  isClockedIn?: boolean;
  isDeleted?: boolean;
  isVerified?: boolean;
  isWorkingOnSunday?: boolean;
  lastClockDate?: Timestamp;
  clockinTime?: Timestamp;
  location?: {
    latitude?: number;
    longitude?: number;
  };
  timestamp?: number;
  netClockedLastly?: number;
  netIncomes?: Record<string, number>;
  pendingAmount?: number;
  pfp_url?: string;
  phoneNumber?: string;
  requirements?: string[];
  sundayTarget?: number;
  userName?: string;
  userRank?: string;
  workedDays?: Record<string, number>;
}

export async function fetchUser(uid: string): Promise<UserData | null> {
  try {
    const ref = doc(db, "users", uid);
    const snap = await getDoc(ref);

    if (snap.exists()) {
      return snap.data() as UserData;
    }
    return null;
  } catch (error) {
    console.error("Error fetching user:", error);
    return null;
  }
}





// general_variables document structure
// Define types if you want strong typing

interface Bike {
  assignedRider: string;
  isAssigned: boolean;
}

interface Battery {
  assignedBike: string;
  assignedRider: string;
  batteryLocation: string;
  batteryName: string;
  offTime: any; // could be firebase.firestore.Timestamp
}

export interface GeneralVariables {
  bikes?: Record<string, Bike>;
  batteries?: Record<string, Battery>;
  [key: string]: any; // catch-all for other fields
}

export async function fetchGeneralVariables(): Promise<GeneralVariables | null> {
  try {
    const docRef = doc(db, "general", "general_variables");
    const docSnap = await getDoc(docRef);

    if (docSnap.exists()) {
      const data = docSnap.data() as GeneralVariables;
      return data;
    } else {
      console.warn("No such document: general/general_variables");
      return null;
    }
  } catch (err) {
    console.error("Error fetching general_variables:", err);
    return null;
  }
}
