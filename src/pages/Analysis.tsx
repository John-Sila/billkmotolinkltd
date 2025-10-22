import { collection, getDocs } from "firebase/firestore";
import { useEffect, useState } from "react";
import toast from "react-hot-toast";
import { db } from "../assets/Firebase";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  ResponsiveContainer,
  Legend,
  Cell,
} from "recharts";

export default function Analysis() {
    const [weeks, setWeeks] = useState<string[]>([]);
    const [selectedWeek, setSelectedWeek] = useState<string | null>(null);
    const [globalMaxGross, setGlobalMaxGross] = useState<number | null>(null);
    const [totals, setTotals] = useState<{ net: number; gross: number; expenses: number } | null>(null);
    const [weekData, setWeekData] = useState<Record<string, any[]>>({});

  useEffect(() => {
    const fetchWeeks = async () => {
        try {
        const deviationsRef = collection(db, "deviations");
        const snapshot = await getDocs(deviationsRef);

        const allData: Record<string, any[]> = {};
        const weekNames: string[] = [];

        for (const doc of snapshot.docs) {
            weekNames.push(doc.id);
            allData[doc.id] = Object.values(doc.data()); // each user's data in that week
        }

        // Sort by latest week number
        weekNames.sort((a, b) => {
            const weekA = parseInt(a.match(/Week\s(\d+)/)?.[1] || "0");
            const weekB = parseInt(b.match(/Week\s(\d+)/)?.[1] || "0");
            return weekB - weekA;
        });

        setWeeks(weekNames);
        setWeekData(allData);

        // Compute global max across all weeks
        const grossValues = Object.values(allData)
            .flatMap((entries: any[]) =>
            entries.flatMap((user: any) =>
                Object.values(user)
                .filter((d: any) => typeof d === "object" && d.grossIncome)
                .map((d: any) => d.grossIncome)
            )
            );

        if (grossValues.length > 0) {
            setGlobalMaxGross(Math.max(...grossValues));
        }

        } catch (err) {
        console.error("Error fetching deviations:", err);
        toast.error("Failed to load weeks");
        }
    };

    fetchWeeks();
    }, []);

    const handleWeekSelect = (weekName: string) => {
    setSelectedWeek(weekName);

    const data = weekData[weekName] || [];
    let totalNet = 0;
    let totalGross = 0;
    let totalExpenses = 0;

    data.forEach((user: any) => {
        Object.values(user).forEach((d: any) => {
        if (typeof d === "object") {
            totalNet += d.netIncome || 0;
            totalGross += d.grossIncome || 0;
            totalExpenses += d.grossIncome - d.netIncome;
        }
        });
    });

    setTotals({ net: totalNet, gross: totalGross, expenses: totalExpenses });
    };


  // Prepare chart data dynamically from totals
  const chartData =
    totals && [
      { name: "Gross Income", value: totals.gross, color: "#16a34a" },
      { name: "Net Income", value: totals.net, color: "#f97316" },
      { name: "Expenses", value: totals.expenses, color: "#dc2626" },
    ];

  return (
    <div className="weekly-deviations p-6">
      <h2 className="text-xl font-semibold mb-4">Weekly Deviations Overview</h2>

      {/* Week Buttons */}
      <div className="weeks-list flex flex-wrap gap-2 mb-6">
        {weeks.map((week) => (
          <button
            key={week}
            className={`week-btn px-3 py-2 rounded-md border text-sm transition-all duration-200 ${
              selectedWeek === week
                ? "bg-blue-600 text-white border-blue-600"
                : "bg-white hover:bg-gray-100 border-gray-300"
            }`}
            onClick={() => handleWeekSelect(week)}
          >
            {week.length > 8 ? week.slice(0, 8) + "…" : week}
          </button>
        ))}
      </div>

      {/* Totals Table */}
      {totals && selectedWeek && (
        <div className="totals-section bg-white p-4 rounded-xl shadow-md">
          <h3 className="text-lg font-medium mb-3">{selectedWeek}</h3>

          <table className="w-full text-sm border-collapse mb-6">
            <thead className="bg-gray-100">
              <tr>
                <th className="p-3 text-left border-b">Total Gross Income</th>
                <th className="p-3 text-left border-b">Total Net Income</th>
                <th className="p-3 text-left border-b">Total Expenses</th>
              </tr>
            </thead>
            <tbody>
              <tr>
                <td className="p-3 border-b text-green-700 font-medium">
                  {totals.gross.toLocaleString()}
                </td>
                <td className="p-3 border-b text-orange-600 font-medium">
                  {totals.net.toLocaleString()}
                </td>
                <td className="p-3 border-b text-red-600 font-medium">
                  {totals.expenses.toLocaleString()}
                </td>
              </tr>
            </tbody>
          </table>

          {/* Animated Bar Chart */}
          <div className="chart-container mt-4" style={{ height: 300 }}>
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={chartData}
                margin={{ top: 20, right: 30, left: 10, bottom: 0 }}
              >
                <CartesianGrid strokeDasharray="3 3" />
                <XAxis dataKey="name" />
                <YAxis domain={[0, globalMaxGross ? globalMaxGross * 1.1 : 0]} />
                <Tooltip />
                <Legend />
                <Bar
                    dataKey="value"
                    animationDuration={1200}
                    radius={[10, 10, 0, 0]}
                    >
                    {chartData && chartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={entry.color} />
                    ))}
                    </Bar>

              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>
      )}
    </div>
  );
}
