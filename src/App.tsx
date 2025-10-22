import { useEffect, useState } from "react";
import { BrowserRouter, Routes, Route, Navigate } from "react-router-dom";
import { onAuthStateChanged, signOut } from "firebase/auth";
import { auth } from "./assets/Firebase";
import Login from "./pages/Login";
import Layout from "./pages/Layout";

import Home from "./pages/Home";
import Settings from "./pages/Settings";
import Profile from "./pages/MyProfile";
import PrimaryLoadingFragment from "./assets/PrimaryLoading";
import Clockin from "./pages/Clockin";
import Chatrooms from "./pages/Chatrooms";
import AdminAndAnalytics from "./pages/AdminAndAnalytics";
import WeeklyReports from "./pages/WeeklyReports";
import DailyReports from "./pages/DailyReports";
import IncidencesAndAccidents from "./pages/IncidencesAndAccidents";
import HumanResource from "./pages/HumanResource";
import Footprints from "./pages/Footprints";
import CashFlowStatements from "./pages/CashFlowStatements";
import IncomeApproval from "./pages/IncomeApproval";
import Profiles from "./pages/Profiles";
import RiderComplaints from "./pages/RiderComplaints";
import Batteries from "./pages/Batteries";
import CreateMemo from "./pages/CreateMemo";
import UserManagement from "./pages/UserManagement";
import Require from "./pages/Require";
import Complain from "./pages/Complain";
import Corrections from "./pages/Corrections";
import Clockout from "./pages/Clockout";
import DamageReports from "./pages/DamageReports";
import Polls from "./pages/Polls";
import PollCreation from "./pages/PollCreation";
import BikesPortal from "./pages/BikesPortal";
import BatteriesPortal from "./pages/BatteriesPortal";
import Destinations from "./pages/Destinations";
import Analysis from "./pages/Analysis";

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState<boolean | null>(null);
  const user = auth.currentUser;

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setIsLoggedIn(!!user);
    });
    return unsubscribe;
  }, []);

  if (isLoggedIn === null) return <p><PrimaryLoadingFragment /></p>;

  document.querySelector("#sideNavHost")?.addEventListener("click", (e: any) => {
    document.getElementById("sideNavHost")!.classList.remove("open");
  })

  return (
    <BrowserRouter>
      <Routes>
        {!isLoggedIn ? (
          <Route path="/*" element={<Login onLogin={() => setIsLoggedIn(true)} />} />
        ) : (
          <Route element={<Layout onLogout={() => signOut(auth)} />}>
            <Route path="/home" element={<Home />} />
            <Route path="/damage_reports" element={<DamageReports />} />
            <Route path="/clock_in" element={<Clockin />} />
            <Route path="/clock_out" element={<Clockout />} />
            <Route path="/corrections" element={<Corrections />} />
            <Route path="/bikes_portal" element={<BikesPortal />} />
            <Route path="/destinations" element={<Destinations />} />
            <Route path="/complains" element={<Complain />} />
            <Route path="/require" element={<Require />} />
            <Route path="/user_management" element={<UserManagement />} />
            <Route path="/create_memo" element={<CreateMemo />} />
            <Route path="/batteries" element={<Batteries />} />
            <Route path="/batteries_portal" element={<BatteriesPortal />} />
            <Route path="/rider_complaints" element={<RiderComplaints />} />
            <Route path="/profiles" element={<Profiles />} />
            <Route path="/income_approval" element={<IncomeApproval />} />
            <Route path="/cash_flow_statements" element={<CashFlowStatements />} />
            <Route path="/polls" element={<Polls />} />
            <Route path="/poll_creation" element={<PollCreation />} />
            <Route path="/footprints" element={<Footprints />} />
            <Route path="/restoration" element={<Settings />} />
            <Route path="/human_resource" element={<HumanResource />} />
            <Route path="/incidences_and_accidents" element={<IncidencesAndAccidents />} />
            <Route path="/daily_reports" element={<DailyReports />} />
            <Route path="/weekly_reports" element={<WeeklyReports />} />
            <Route path="/analysis" element={<Analysis />} />
            <Route path="/admin_and_analytics" element={<AdminAndAnalytics />} />
            <Route path="/chatrooms" element={<Chatrooms />} />
            <Route path="/my_profile" element={<Profile />} />
            <Route path="*" element={<Navigate to="/home" />} />
          </Route>
        )}
      </Routes>
    </BrowserRouter>
  );
}

export default App;
