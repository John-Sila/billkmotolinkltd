import { doc, getDoc } from "firebase/firestore";
import { useEffect, useState } from "react";
import { db } from "../assets/Firebase";
import toast from "react-hot-toast";
import { fetchUser, type UserData } from "../services/userService";
import { getAuth, onAuthStateChanged } from "firebase/auth";

interface Battery {
  batteryName?: string;
  batteryLocation?: string;
  assignedBike?: string;
  assignedRider?: string;
  offTime?: { seconds: number; nanoseconds: number };
  isAssigned?: boolean;
}

export default function BatteriesFragment() {
    const [batteries, setBatteries] = useState<Battery[]>([]);
    const [loading, setLoading] = useState(true);
    const [uid, setUid] = useState<string | null>(null);
    const [user, setUser] = useState<UserData | null>(null);
    const [userName, setUserName] = useState<string>("");

    // on component load, check auth state
    useEffect(() => {
        const auth = getAuth();
        const unsubscribe = onAuthStateChanged(auth, (firebaseUser) => {
            if (firebaseUser) {
            setUid(firebaseUser.uid);
            } else {
            setUid(null);
            setLoading(false);
            }
        });

        return () => unsubscribe();
    }, []);

    // after uid, fetch data
    useEffect(() => {
    if (!uid) return;

    async function loadUser() {
        const userData = await fetchUser(uid || "");

        setUser(userData);
        setUserName(userData?.userName || "")
        setLoading(false);
    }

    loadUser();
    }, [uid]);


    useEffect(() => {
        const fetchBatteries = async () => {
            try {
                const generalRef = doc(db, "general", "general_variables");
                const snapshot = await getDoc(generalRef);

                if (!snapshot.exists()) {
                toast.error("No batteries record found");
                setBatteries([]);
                setLoading(false);
                return;
                }

                const data = snapshot.data();
                const allBatteries = data.batteries || {};

                // Corrected filter conditions
                const filtered = Object.values(allBatteries).filter((b: any) => {
                const isAssigned = b.isAssigned ?? false;
                const assignedRider = b.assignedRider || "";
                
                // Include battery if:
                // 1. It's not assigned (isAssigned is false), OR
                // 2. It is assigned AND assigned to the current user
                return !isAssigned || 
                        (isAssigned && assignedRider.toLowerCase() === userName.toLowerCase());
                });

                setBatteries(filtered);
            } catch (err) {
                console.error("Error fetching batteries:", err);
                toast.error("Failed to load batteries");
            } finally {
                setLoading(false);
            }
        };

        fetchBatteries();
    }, [userName]);

    const formatTimeAgo = (timestamp: any) => {
        if (!timestamp) return "N/A";
        const date = timestamp.toDate ? timestamp.toDate() : new Date(timestamp);
        const diffMs = Date.now() - date.getTime();
        const diffMins = Math.floor(diffMs / 60000);
        const diffHours = Math.floor(diffMins / 60);
        const diffDays = Math.floor(diffHours / 24);

        if (diffMins < 1) return "Just now";
        if (diffMins < 60) return `${diffMins} min${diffMins !== 1 ? "s" : ""} ago`;
        if (diffHours < 24)
            return `${diffHours} hr${diffHours !== 1 ? "s" : ""} ago`;
        return `${diffDays} day${diffDays !== 1 ? "s" : ""} ago`;
    };

  return (
    <div className="allBatteries">
      <h2>Battery Overview</h2>

      {loading ? (
        <p className="loading-text">Loading batteries...</p>
      ) : batteries.length === 0 ? (
        <p className="no-data">No batteries found.</p>
      ) : (
        <table className="battery-table">
          <thead>
            <tr>
              <th>Battery Name</th>
              <th>Location</th>
              <th>Off Time</th>
            </tr>
          </thead>
          <tbody>
            {batteries.map((battery, index) => (
              <tr key={index}>
                <td>{battery.batteryName}</td>
                <td>{battery.batteryLocation}</td>
                <td>{formatTimeAgo(battery.offTime)}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
