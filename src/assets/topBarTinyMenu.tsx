import { useEffect, useState } from "react";
import { NavLink } from "react-router-dom";
import { Link } from "react-router-dom";
import { fetchUser, type UserData } from "../services/userService";
import { getAuth, onAuthStateChanged } from "firebase/auth";
interface SideNavProps {
  onLogout: () => void;
}

export const TopBarTinyMenu = ({ onLogout }: SideNavProps) => {
    
  const [user, setUser] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);
  const [uid, setUid] = useState<string | null>(null);
  const [userRank, setUserRank] = useState<string>("");

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
            const data = await fetchUser(uid || "");
            setUser(data);
            setUserRank(data?.userRank || "")
            setLoading(false);
        }

        loadUser();
    }, [uid]);

    return (
        <div className="tinyMenuContainer" id="tinyMenuContainer" onClick={() => {
            const tinyMenuContainer = document.getElementById("tinyMenuContainer");
              const topBar = document.getElementById("topBar");
              if (tinyMenuContainer && topBar) {
                if (tinyMenuContainer.style.display == "none") {
                  topBar?.classList.add("radiusPlay");
                } else {
                  topBar?.classList.remove("radiusPlay");
                }
                tinyMenuContainer.style.display = tinyMenuContainer.style.display == "flex" ? "none" : "flex";
              }
        } }>

            <svg className="wave" viewBox="0 0 1440 320" xmlns="http://www.w3.org/2000/svg">
                <path
                d="M0,256L11.4,240C22.9,224,46,192,69,192C91.4,192,114,224,137,234.7C160,245,183,235,206,213.3C228.6,192,251,160,274,149.3C297.1,139,320,149,343,181.3C365.7,213,389,267,411,282.7C434.3,299,457,277,480,250.7C502.9,224,526,192,549,181.3C571.4,171,594,181,617,208C640,235,663,277,686,256C708.6,235,731,149,754,122.7C777.1,96,800,128,823,165.3C845.7,203,869,245,891,224C914.3,203,937,117,960,112C982.9,107,1006,181,1029,197.3C1051.4,213,1074,171,1097,144C1120,117,1143,107,1166,133.3C1188.6,160,1211,224,1234,218.7C1257.1,213,1280,139,1303,133.3C1325.7,128,1349,192,1371,192C1394.3,192,1417,128,1429,96L1440,64L1440,320L1428.6,320C1417.1,320,1394,320,1371,320C1348.6,320,1326,320,1303,320C1280,320,1257,320,1234,320C1211.4,320,1189,320,1166,320C1142.9,320,1120,320,1097,320C1074.3,320,1051,320,1029,320C1005.7,320,983,320,960,320C937.1,320,914,320,891,320C868.6,320,846,320,823,320C800,320,777,320,754,320C731.4,320,709,320,686,320C662.9,320,640,320,617,320C594.3,320,571,320,549,320C525.7,320,503,320,480,320C457.1,320,434,320,411,320C388.6,320,366,320,343,320C320,320,297,320,274,320C251.4,320,229,320,206,320C182.9,320,160,320,137,320C114.3,320,91,320,69,320C45.7,320,23,320,11,320L0,320Z"
                fill-opacity="1"
                ></path>
            </svg>

            <div className="topBarTinyMenu" id="topBarTinyMenu">
                {
                    userRank == "Admin" || userRank == "Systems, IT" &&
                    <>
                        <ul className="list">
                            <li className="element">
                                <NavLink to="/"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M240-120q-50 0-85-35t-35-85v-240q0-24 9-46t26-39l240-240q17-18 39.5-26.5T480-840q23 0 45 8.5t40 26.5l30 30-315 315v180h400v-180L536-604l115-114 154 153q17 17 26 39t9 46v240q0 50-35 85t-85 35H240Z"/></svg>
                                    <label>Home</label>
                                </NavLink>
                            </li>

                            <li className="element">
                                <NavLink to="/damage_reports"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M200-160v-80h64l79-263q8-26 29.5-41.5T420-560h120q26 0 47.5 15.5T617-503l79 263h64v80H200Zm240-480v-200h80v200h-80Zm238 99-57-57 142-141 56 56-141 142Zm42 181v-80h200v80H720ZM282-541 141-683l56-56 142 141-57 57ZM40-360v-80h200v80H40Z"/></svg>
                                    <label>Damages</label>
                                </NavLink>
                            </li>
                        </ul>
                        <div className="separator"></div>
                        <ul className="list">
                            <li className="element">
                                <NavLink to="/clock_in"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M480-80q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Zm0-80q134 0 227-93t93-227H480v-320q-134 0-227 93t-93 227q0 134 93 227t227 93Z"/></svg>
                                    <label>Clock In</label>
                                </NavLink>
                            </li>

                            <li className="element delete">
                                <NavLink to="/clock_out"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Clock Out</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/corrections"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Rectify</label>
                                </NavLink>
                            </li>
                        </ul>
                        <div className="separator"></div>
                        <ul className="list">
                            <li className="element delete">
                                    <NavLink to="/batteries"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Batteries</label>
                                    </NavLink>
                                </li>
                            <li className="element">
                                <NavLink to="/bikes_portal"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M480-80q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Zm0-80q134 0 227-93t93-227H480v-320q-134 0-227 93t-93 227q0 134 93 227t227 93Z"/></svg>
                                    <label>Manage Bikes</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/batteries_portal"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Manage Batteries</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/destinations"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Destinations</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/user_management"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Users</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/require"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Require</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/daily_reports"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Daily Reports</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/weekly_reports"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Weekly Reports</label>
                                </NavLink>
                            </li>
                            <li className="element delete">
                                <NavLink to="/analysis"
                                className={({ isActive }) => isActive ? "active-link" : ""}>
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                    <label>Analysis</label>
                                </NavLink>
                            </li>
                        </ul>
                        <div className="separator"></div>
                        <ul className="list">
                            <li className="element delete" onClick={onLogout}>
                                <Link to="">
                                    <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M200-120q-33 0-56.5-23.5T120-200v-120h80v120h560v-480H200v120h-80v-200q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm260-140-56-56 83-84H120v-80h367l-83-84 56-56 180 180-180 180Z"/></svg>
                                    <label>Log Out</label>
                                </Link>
                            </li>
                        </ul>
                    </>
                }
                {
                    userRank == "Rider" && (
                        <>
                            <ul className="list">
                                <li className="element">
                                    <NavLink to="/"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M240-120q-50 0-85-35t-35-85v-240q0-24 9-46t26-39l240-240q17-18 39.5-26.5T480-840q23 0 45 8.5t40 26.5l30 30-315 315v180h400v-180L536-604l115-114 154 153q17 17 26 39t9 46v240q0 50-35 85t-85 35H240Z"/></svg>
                                        <label>Home</label>
                                    </NavLink>
                                </li>

                                <li className="element">
                                    <NavLink to="/damage_reports"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M200-160v-80h64l79-263q8-26 29.5-41.5T420-560h120q26 0 47.5 15.5T617-503l79 263h64v80H200Zm240-480v-200h80v200h-80Zm238 99-57-57 142-141 56 56-141 142Zm42 181v-80h200v80H720ZM282-541 141-683l56-56 142 141-57 57ZM40-360v-80h200v80H40Z"/></svg>
                                        <label>Damages</label>
                                    </NavLink>
                                </li>
                            </ul>
                            <div className="separator"></div>
                            <ul className="list">
                                <li className="element">
                                    <NavLink to="/clock_in"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M480-80q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Zm0-80q134 0 227-93t93-227H480v-320q-134 0-227 93t-93 227q0 134 93 227t227 93Z"/></svg>
                                        <label>Clock In</label>
                                    </NavLink>
                                </li>

                                <li className="element delete">
                                    <NavLink to="/clock_out"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Clock Out</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/corrections"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Rectify</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/batteries"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Batteries</label>
                                    </NavLink>
                                </li>
                            </ul>
                            <div className="separator"></div>
                            <ul className="list">
                                <li className="element delete" onClick={onLogout}>
                                    <Link to="">
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M200-120q-33 0-56.5-23.5T120-200v-120h80v120h560v-480H200v120h-80v-200q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm260-140-56-56 83-84H120v-80h367l-83-84 56-56 180 180-180 180Z"/></svg>
                                        <label>Log Out</label>
                                    </Link>
                                </li>
                            </ul>
                        </>
                    )
                }
                {
                    userRank == "CEO" && (
                        <>
                            <ul className="list">
                                <li className="element">
                                    <NavLink to="/"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M240-120q-50 0-85-35t-35-85v-240q0-24 9-46t26-39l240-240q17-18 39.5-26.5T480-840q23 0 45 8.5t40 26.5l30 30-315 315v180h400v-180L536-604l115-114 154 153q17 17 26 39t9 46v240q0 50-35 85t-85 35H240Z"/></svg>
                                        <label>Home</label>
                                    </NavLink>
                                </li>
                            </ul>
                            <div className="separator"></div>
                            <ul className="list">
                                <li className="element delete">
                                    <NavLink to="/batteries"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Batteries</label>
                                    </NavLink>
                                </li>
                                <li className="element">
                                    <NavLink to="/bikes_portal"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M480-80q-83 0-156-31.5T197-197q-54-54-85.5-127T80-480q0-83 31.5-156T197-763q54-54 127-85.5T480-880q83 0 156 31.5T763-763q54 54 85.5 127T880-480q0 83-31.5 156T763-197q-54 54-127 85.5T480-80Zm0-80q134 0 227-93t93-227H480v-320q-134 0-227 93t-93 227q0 134 93 227t227 93Z"/></svg>
                                        <label>Manage Bikes</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/batteries_portal"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Manage Batteries</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/destinations"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Destinations</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/user_management"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Users</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/require"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Require</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/daily_reports"
                                        className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Daily Reports</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/weekly_reports"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Weekly Reports</label>
                                    </NavLink>
                                </li>
                                <li className="element delete">
                                    <NavLink to="/analysis"
                                    className={({ isActive }) => isActive ? "active-link" : ""}>
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M340-180q-125 0-212.5-87.5T40-480q0-125 87.5-212.5T340-780q125 0 212.5 87.5T640-480q0 125-87.5 212.5T340-180Zm400 20v-488l-44 44-56-56 140-140 140 140-57 56-43-43v487h-80ZM420-340l56-56-96-97v-147h-80v180l120 120Z"/></svg>
                                        <label>Analysis</label>
                                    </NavLink>
                                </li>
                            </ul>
                            <div className="separator"></div>
                            <ul className="list">
                                <li className="element delete" onClick={onLogout}>
                                    <Link to="">
                                        <svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#9A9A9AFF"><path d="M200-120q-33 0-56.5-23.5T120-200v-120h80v120h560v-480H200v120h-80v-200q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm260-140-56-56 83-84H120v-80h367l-83-84 56-56 180 180-180 180Z"/></svg>
                                        <label>Log Out</label>
                                    </Link>
                                </li>
                            </ul>
                        </>
                    )
                }
            </div>
        </div>
    )
}