import { useEffect, useState } from "react";
import { collection, getDocs, getDoc, doc, updateDoc } from "firebase/firestore";
import { db } from "../assets/Firebase";

interface UserProfile {
  [key: string]: any; // dynamic fields
}

export default function Profiles() {
    const [users, setUsers] = useState<{ uid: string; userName: string }[]>([]);
    const [selectedUser, setSelectedUser] = useState<UserProfile | null>(null);
    const [selectedUid, setSelectedUid] = useState<string | null>(null);

    // Fetch all users on mount
    useEffect(() => {
      const fetchUsers = async () => {
        const usersSnapshot = await getDocs(collection(db, "users"));
        const fetchedUsers = usersSnapshot.docs
          .map(doc => {
            const data = doc.data();
            return {
              uid: doc.id,
              userName: data.userName || "Unknown",
              userRank: data.userRank || "Unknown",
            };
          })
          .filter(user => {
            // Filter out users with CEO rank
            return user.userRank.toLowerCase() !== "ceo";
          });

        setUsers(fetchedUsers);
      };

      fetchUsers();
    }, []);

    const parameters = [
      { label: "User Name", key: "userName", editable: false },
      { label: "Phone", key: "phoneNumber", editable: false },
      { label: "Email Verified", key: "isVerified", editable: false },
      { label: "Net Clocked Lastly", key: "netClockedLastly", editable: false },
      { label: "Current Bike", key: "currentBike", editable: false },
      { label: "Pending Amount", key: "pendingAmount", editable: true },
      { label: "National ID", key: "idNumber", editable: false },
      { label: "Gender", key: "gender", editable: false },
      { label: "Role", key: "userRank", editable: false },
      { label: "Clocked in", key: "isClockedIn", editable: false },
      { label: "Weekday Target", key: "dailyTarget", editable: true },
      { label: "Sunday Target", key: "sundayTarget", editable: true },
      { label: "Sunday Clocking", key: "isWorkingOnSunday", editable: true },
      { label: "Requirements", key: "requirements", editable: false },
      { label: "In-App Balance", key: "currentInAppBalance", editable: true },
    ];

    function getFieldType(value: any): "boolean" | "number" | "string" | "map" | "unknown" {
      if (typeof value === "boolean") return "boolean";
      if (typeof value === "number") return "number";
      if (typeof value === "string") return "string";
      if (typeof value === "object" && value !== null) return "map";
      return "unknown";
    }


    const handleUserClick = async (uid: string) => {
      try {
        const userRef = doc(db, "users", uid);
        const userSnap = await getDoc(userRef);

        if (!userSnap.exists()) {
          console.warn("User not found:", uid);
          setSelectedUser(null);
          return;
        }

        setSelectedUser(userSnap.data());
        setSelectedUid(uid);
      } catch (err) {
        console.error("Error fetching user:", err);
      }
    };

    const handleEditField = async (key: string) => {
      if (!selectedUid || !selectedUser) return;

      const value = selectedUser[key];
      const type = getFieldType(value);

      switch (type) {
        case "boolean":
          if (window.confirm(`${value ? "Deny user?" : "Allow user?"}?`)) {
            const newValue = !value;
            await updateDoc(doc(db, "users", selectedUid), { [key]: newValue });
            setSelectedUser({ ...selectedUser, [key]: newValue });
          }
          break;

        case "number":
          {
            const input = window.prompt(`Enter new value for ${key}:`, value);
            if (input === null) return; // cancelled
            const num = Number(input);
            if (isNaN(num)) {
              alert("Invalid number.");
              return;
            }
            await updateDoc(doc(db, "users", selectedUid), { [key]: num });
            setSelectedUser({ ...selectedUser, [key]: num });
          }
          break;

        case "string":
          {
            const input = window.prompt(`Enter new value for ${key}:`, value);
            if (input === null) return;
            await updateDoc(doc(db, "users", selectedUid), { [key]: input });
            setSelectedUser({ ...selectedUser, [key]: input });
          }
          break;

        case "map":
          {
            if (window.confirm(`Delete entire ${key} map? This cannot be undone.`)) {
              await updateDoc(doc(db, "users", selectedUid), { [key]: {} });
              setSelectedUser({ ...selectedUser, [key]: {} });
            }
          }
          break;

        default:
          alert(`Unsupported field type for ${key}.`);
          break;
      }
    };


    return (
    <div className="profiles-container">
      <h2>All Users</h2>

      {/* Buttons for each user */}
      <div className="user-buttons">
        {users.map(user => (
          <button
            key={user.uid}
            onClick={() => handleUserClick(user.uid)}
            style={{ margin: "4px", padding: "6px 12px" }}
          >
            {user.userName}
          </button>
        ))}
      </div>

      {/* User profile table */}
      {selectedUser && (
        <div className="user-profile-table" style={{ marginTop: "20px" }}>
          <h3>{selectedUser.userName || "Profile"}</h3>
          <table style={{ width: "100%", borderCollapse: "collapse" }}>
            <thead>
              <tr>
                <th >Parameter</th>
                <th >Value</th>
                <th >Action</th>
              </tr>
            </thead>
            <tbody>
              {parameters.map(({ label, key, editable }) => {
                let value = selectedUser?.[key];

                // Format booleans
                if (typeof value === "boolean") value = value ? "Yes" : "No";
                // Format arrays/objects
                if (Array.isArray(value)) value = value.length;
                if (typeof value === "object" && value !== null) value = Object.keys(value).length;

                // Fallback
                if (value === undefined || value === null) value = "-";

                return (
                  <tr key={key}>
                    <td>{label}</td>
                    <td>{value}</td>
                    <td>
                        <button
                          disabled={!editable}
                          onClick={() => handleEditField(key)}
                        >
                          Edit
                        </button>
                      </td>
                  </tr>
                );
              })}
            </tbody>

          </table>
        </div>
      )}
    </div>
  );
}

