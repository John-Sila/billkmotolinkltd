import { useEffect, useState } from "react";
import AlertDialog from "../assets/Dialog";
import toast, { Toaster } from "react-hot-toast";
import { doc, query, where, updateDoc, getDocs, collection} from "firebase/firestore";
import logo from "../assets/logo2.png";
import { db } from "../assets/Firebase";

export default function Require() {

  const [users, setUsers] = useState<any[]>([]);
  const [selectedUserToRequire, setSelectedUserToRequire] = useState("");
  const [appBal, setAppBal] = useState<string | null>(null)
  const [selectedDate, setSelectedDate] = useState<string | null>(null);
  const [openRequireDialog, setOpenRequireDialog] = useState<boolean>(false)

  interface UserData {
    id: string;
    userName?: string;
    isDeleted?: boolean;
    userRank?: string;
  }

  useEffect(() => {
    const fetchUsers = async () => {
      try {
        const snapshot = await getDocs(collection(db, "users"));
        const fetchedUsers: UserData[] = snapshot.docs
          .map((doc) => ({ 
            id: doc.id, 
            ...doc.data() 
          } as UserData))
          .filter(
            (u) =>
              !u.isDeleted && // exclude deleted users
              ["Rider", "Admin", "Systems, IT"].includes(u.userRank || "") // filter by role
          );

        setUsers(fetchedUsers);
      } catch (error) {
        console.error("Error fetching users:", error);
      }
    };

    fetchUsers();
  }, []);

  const handleDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    // If input is cleared, set it to null
    setSelectedDate(value ? value : null);
  };

  const RequireUser = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    if (!selectedUserToRequire || selectedUserToRequire.trim() == "") {
      return toast("Select a name.", {
          icon: "❗",
          style: {
              borderRadius: "10px",
              background: "#fff",
              color: "red",
          },
      });
    }
    if (!appBal || appBal.trim() == "") {
      return toast("Enter the in-app balance to be used.", {
          icon: "❗",
          style: {
              borderRadius: "10px",
              background: "#fff",
              color: "red",
          },
      });
    }
    if (!selectedDate || selectedDate.trim() == "") {
      return toast("Select a valid date.", {
          icon: "❗",
          style: {
              borderRadius: "10px",
              background: "#fff",
              color: "red",
          },
      });
    }
    setOpenRequireDialog(true)
  }

  const handleRequireConfirm = async () => {
    setOpenRequireDialog(false)

    if (!selectedUserToRequire || !selectedDate || appBal === null) {
      toast.error("Please select a user, date, and enter app balance");
      return;
    }

    try {
      toast.loading("Adding requirement...");

      // Convert selectedDate to Date object (assuming selectedDate is in YYYY-MM-DD format)
      const date = new Date(selectedDate);
      
      // Get week of year (similar to Calendar.WEEK_OF_YEAR)
      const getWeekOfYear = (date: Date) => {
        const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
        const pastDaysOfYear = (date.getTime() - firstDayOfYear.getTime()) / 86400000;
        return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
      };

      const weekOfYear = getWeekOfYear(date);

      // Get Monday of the week
      const weekStart = new Date(date);
      const day = weekStart.getDay();
      const diff = weekStart.getDate() - day + (day === 0 ? -6 : 1); // adjust when day is Sunday
      weekStart.setDate(diff);

      // Get Sunday of the week
      const weekEnd = new Date(weekStart);
      weekEnd.setDate(weekStart.getDate() + 6);

      // Formatters
      const formatDate = (date: Date) => {
        return date.toLocaleDateString('en-GB', {
          day: '2-digit',
          month: 'short',
          year: 'numeric'
        }).replace(/ /g, ' ');
      };

      const formatDayOfWeek = (date: Date) => {
        return date.toLocaleDateString('en-GB', { weekday: 'long' });
      };

      // Format the dates
      const selectedDateFormatted = formatDate(date);
      const selectedDayOfWeek = formatDayOfWeek(date);
      const weekRangeText = `Week ${weekOfYear} (${formatDate(weekStart)} to ${formatDate(weekEnd)})`;

      // Prepare the requirement entry
      const requirementEntry = {
        date: selectedDateFormatted,
        weekRange: weekRangeText,
        dayOfWeek: selectedDayOfWeek,
        appBalance: parseFloat(appBal) // convert string to number
      };

      // Find user by userName and update requirements
      const usersRef = collection(db, "users");
      const q = query(usersRef, where("userName", "==", selectedUserToRequire));
      const querySnapshot = await getDocs(q);

      if (querySnapshot.empty) {
        toast.dismiss();
        toast.error(`${selectedUserToRequire}`);
        return;
      }

      const userDoc = querySnapshot.docs[0];
      const userRef = doc(db, "users", userDoc.id);

      // Update the requirements field
      await updateDoc(userRef, {
        [`requirements.${Date.now()}`]: requirementEntry // using timestamp as unique key
      });

      toast.dismiss();
      toast.success("Requirement added successfully!");
      
      // Reset form
      setSelectedUserToRequire("");
      setSelectedDate(null);
      setAppBal(null);

    } catch (error) {
      toast.dismiss();
      toast.error("Failed to add requirement");
      console.error("Error adding requirement:", error);
    }

  };

  const handleRequireClose = () => {
    setOpenRequireDialog(false)
  }

  return (
    <div className="clockouts-container">
      <div><Toaster /></div>
      <form className="form_container" onSubmit={RequireUser}>
          <div className="logo_container">
          <img className="logo" src={logo} alt="logo" width={150} height={150} />
          </div>
          <div className="title_container">
          <p className="title">Requirements</p>
          <span className="subtitle">Require for a faulty clockout</span>
          </div>
          <br />

          <div>
              <table>
                  <thead>
                  <tr>
                      <th>Parameter</th>
                      <th>Value</th>
                  </tr>
                  </thead>

                  <tbody>

                  {/* user */}
                  <tr>
                    <td><label className="input_label" htmlFor="user">User</label></td>
                    <td>
                      <select
                        title="Select User"
                        className="styled-select"
                        value={selectedUserToRequire}
                        onChange={(e) => setSelectedUserToRequire(e.target.value)}
                      >
                        <option value="">Select user</option>
                        {users.map((user) => (
                          <option key={user.id} value={user.userName}>
                            {user.userName || "Unnamed User"}
                          </option>
                        ))}
                      </select>
                    </td>
                  </tr>

                  {/* In App Bal */}
                  <tr>
                      <td><label className="input_label" htmlFor="appBalance">App Balance</label></td>
                      <input
                          type="number"
                          name="appBalance"
                          id="appBalance"
                          onWheel={e => e.currentTarget.blur()}
                          value={appBal || ""}
                          onChange={(e) => setAppBal(e.target.value)}
                          title="In App Balance" />
                  </tr>

                  {/* Date */}
                  <tr>
                      <td><label className="input_label" htmlFor="appBalance">Date to correct</label></td>
                      <input
                        id="date"
                        type="date"
                        title="Select the date you want to require"
                        value={selectedDate ?? ""} // fallback to empty string if null
                        onChange={handleDateChange}
                      />
                  </tr>

                  </tbody>
              </table>

              <button title="Require" type="submit" className="sign-in_btn">
                  <span>Push Requirement</span>
              </button>

          </div>

          <div className="separator">
          <hr className="line" />
          <span className="note">Internal Operations</span>
          <hr className="line" />
          </div>
      </form>

      <AlertDialog
          open={openRequireDialog}
          title="Confirm action"
          description="Are you sure you want to add this requirement?"
          onConfirm={handleRequireConfirm}
          onClose={handleRequireClose}
          />
    </div>
  );
}
