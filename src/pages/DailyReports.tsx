import { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import toast, { Toaster } from "react-hot-toast";
import { db } from "../assets/Firebase";
import { formatCurrency } from "../assets/CurrencyFormatter";

export default function DailyReports() {
  const [usersData, setUsersData] = useState<any[]>([]);
  const [selectedUser, setSelectedUser] = useState<string | null>(null);

  useEffect(() => {
    const fetchClockouts = async () => {
      try {
        const usersSnapshot = await getDocs(collection(db, "users"));

        const fetched = usersSnapshot.docs
          .map((doc) => {
            const data = doc.data();
            const userRank = data.userRank || "";
            const isDeleted = data.isDeleted || false;
            const clockouts = data.clockouts || {};
            
            // Filter users based on conditions
            const isValidUser = 
              (userRank === "Rider" || userRank === "Admin") && 
              !isDeleted;

            if (!isValidUser) {
              return null; // Exclude invalid users
            }

            const parsedClockouts = Object.entries(clockouts)
              .map(([date, record]: [string, any]) => ({
                date,
                ...record,
              }))
              // sort by posted_at timestamp descending if available
              .sort(
                (a, b) =>
                  (b.posted_at?.seconds || 0) - (a.posted_at?.seconds || 0)
              );

            // Only include users who have at least one clockout
            if (parsedClockouts.length === 0) {
              return null;
            }

            return {
              userName: data.userName || "Unknown User",
              uid: doc.id,
              clockouts: parsedClockouts,
            };
          })
          .filter(user => user !== null); // Remove null entries

        if (fetched.length === 0) {
          toast.error("No valid clockouts found");
        } else {
          toast.success(`Loaded ${fetched.length} users with clockouts`);
        }
        setUsersData(fetched);
      } catch (error) {
        toast.dismiss();
        toast.error("Failed to load clockouts");
        console.error("Error fetching clockouts:", error);
      }
    };

    fetchClockouts();
  }, []);


  return (
    <div className="dr-dashboard">
      <div><Toaster /></div>
      {/* User selection buttons */}
      <div className="user-list">
        {usersData.map((user) => (
          <button
            key={user.uid}
            onClick={() => setSelectedUser(user.uid)}
            className={`user-btn ${selectedUser === user.uid ? "active" : ""}`}
            style={{
              borderRadius: "8px",
              padding: "8px 16px",
              background: selectedUser === user.uid ? "#269b24" : "",
              color: selectedUser === user.uid ? "#fff" : "",
              cursor: "pointer",
              border: "none",
            }}
          >
            {user.userName}
          </button>
        ))}
      </div>

      {/* Clockouts for selected user */}
      {selectedUser && (
        <div className="clockouts-section" style={{ marginTop: "20px" }}>
          <h3>
            {usersData.find((u) => u.uid === selectedUser)?.userName}'s Clockouts
          </h3>

          <div className="clockout-list">
            {usersData
              .find((u) => u.uid === selectedUser)
              ?.clockouts.map((entry: any) => (
                <div
                  key={entry.date}
                  className="dr-card"
                >
                  <p><strong>Date:</strong> {entry.date}</p>
                  <p><strong>Net Income:</strong> {formatCurrency(entry.netIncome)}</p>
                  <p><strong>Gross Income:</strong> {formatCurrency(entry.grossIncome)}</p>
                  {entry.expenses && Object.keys(entry.expenses).length > 0 && (
                    <div className="expenses-section">
                      <p><strong>Expenses:</strong></p>
                      <ul>
                        {Object.entries(entry.expenses).map(([key, value]) => (
                          <li key={key}>
                            {key}: {formatCurrency(value as number)}
                          </li>
                        ))}
                      </ul>
                    </div>
                  )}
                  <p><strong>Mileage Covered:</strong> {entry.mileageDifference} KM</p>
                  <p><strong>Posted:</strong> <i>{entry.posted_at?.toDate?.().toLocaleString() ?? "—"}</i></p>
                </div>
              ))}
          </div>
        </div>
      )}
    </div>
  );
}
