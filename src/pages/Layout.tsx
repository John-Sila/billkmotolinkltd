import { Outlet } from "react-router-dom";
import SideNav from "../assets/SideNav";
import TopBar from "../assets/TopBar";
import { TopBarTinyMenu } from "../assets/topBarTinyMenu";
// import { BottomBar } from "../assets/BottomBar";

interface LayoutProps {
  onLogout: () => void;
}

export default function Layout({ onLogout }: LayoutProps) {
  return (
    <div className="layout">
      <SideNav onLogout={onLogout} />
      <div className="main-content">
        <TopBar />
        <main className="content">
          <TopBarTinyMenu onLogout={onLogout} />
          <Outlet />
          {/* <BottomBar /> */}
        </main>
      </div>
    </div>
  );
}
