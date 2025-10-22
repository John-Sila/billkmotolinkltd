/* eslint-disable @typescript-eslint/no-explicit-any */
import React, { useEffect, useState } from "react";
import { collection, getDocs } from "firebase/firestore";
import { db } from "../assets/Firebase";

const WeeklyReports = () => {
  const [weeks, setWeeks] = useState<any[]>([]);
  const [selectedWeek, setSelectedWeek] = useState<string | null>(null);
  const [selectedUser, setSelectedUser] = useState<string | null>(null);
  const [weekData, setWeekData] = useState<any | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const fetchWeeks = async () => {
      setLoading(true);
      const querySnap = await getDocs(collection(db, "deviations"));
      const weekDocs = querySnap.docs.map((doc) => ({
        id: doc.id,
        data: doc.data(),
      }));
      setWeeks(weekDocs);
      setLoading(false);
    };

    fetchWeeks();
  }, []);

  const handleWeekClick = (weekId: string, weekData: any) => {
    setSelectedWeek(weekId);
    setWeekData(weekData);
    setSelectedUser(null);
  };

  const handleUserClick = (userName: string) => {
    setSelectedUser(userName);
  };

  const getUserData = (userName: string) => {
    if (!weekData || !weekData[userName]) return {};
    return weekData[userName];
  };

  const getTotals = (userDays: any) => {
    const totals = {
      grossIncome: 0,
      netIncome: 0,
      grossDeviation: 0,
      netDeviation: 0,
      netGrossDifference: 0,
    };

    Object.values(userDays).forEach((day: any) => {
      totals.grossIncome += day.grossIncome || 0;
      totals.netIncome += day.netIncome || 0;
      totals.grossDeviation += day.grossDeviation || 0;
      totals.netDeviation += day.netDeviation || 0;
      totals.netGrossDifference += day.netGrossDifference || 0;
    });

    return totals;
  };


  // Sort by the start date embedded inside the week name
  const sortedWeeks = weeks.sort((a, b) => {
    const extractStartDate = (weekName: string) => {
      const match = weekName.match(/\((\d{1,2} [A-Za-z]{3} \d{4})/);
      if (!match) return 0;
      // Parse "20 Oct 2025" into a valid Date
      return new Date(match[1]).getTime();
    };

    const dateA = extractStartDate(a.id);
    const dateB = extractStartDate(b.id);

    return dateB - dateA; // newest week first
  });


  if (loading) return <p>Loading weekly deviations...</p>;

  return (
    <div className="weekly-deviations">
      {/* Week Buttons */}
      <div className="week-buttons">
        {sortedWeeks.map((week) => {
          const truncatedName =
            week.id.length > 8 ? week.id.substring(0, 8) + "…" : week.id;

          return (
            <button
              key={week.id}
              className={`btn ${selectedWeek === week.id ? "active" : ""}`}
              onClick={() => handleWeekClick(week.id, week.data)}
              title={week.id} // Tooltip with full name
            >
              {truncatedName}
            </button>
          );
        })}
      </div>


      {/* User Buttons */}
      {selectedWeek && weekData && (
        <div className="user-buttons">
          {Object.keys(weekData).map((user) => (
            <button
              key={user}
              className={`btn ${selectedUser === user ? "active" : ""}`}
              onClick={() => handleUserClick(user)}
            >
              {user}
            </button>
          ))}
        </div>
      )}

      {/* Table for Selected User */}
      {selectedUser && (
        <div className="user-week-table">
          <table>
            <thead>
              <tr>
                <th>Day</th>
                <th>Gross</th>
                <th>Net</th>
                <th>Gross Dev</th>
                <th>Gross - Net</th>
              </tr>
            </thead>
            <tbody>
              {Object.entries(getUserData(selectedUser))
                .sort(([a], [b]) =>
                  ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].indexOf(a) -
                  ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"].indexOf(b)
                )
                .map(([day, values]: any) => {
                  // Convert full day name to three-letter abbreviation
                  const shortDay = day.slice(0, 3); // "Monday" → "Mon"
                  return (
                    <tr key={day}>
                      <td>{shortDay}</td>
                      <td>{values.grossIncome?.toLocaleString()}</td>
                      <td>{values.netIncome?.toLocaleString()}</td>
                      <td>{values.grossDeviation?.toLocaleString()}</td>
                      <td>{values.netGrossDifference?.toLocaleString()}</td>
                    </tr>
                  );
                })}
            </tbody>


            {/* Totals Row */}
            <tfoot>
              {(() => {
                const totals = getTotals(getUserData(selectedUser));
                return (
                  <tr className="totals-row">
                    <td><strong>Total</strong></td>
                    <td><strong>{totals.grossIncome.toLocaleString()}</strong></td>
                    <td><strong>{totals.netIncome.toLocaleString()}</strong></td>
                    <td><strong>{totals.grossDeviation.toLocaleString()}</strong></td>
                    <td><strong>{totals.netGrossDifference.toLocaleString()}</strong></td>
                  </tr>
                );
              })()}
            </tfoot>
          </table>
        </div>
      )}
    </div>
  );
};

export default WeeklyReports;
