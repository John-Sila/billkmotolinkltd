import { useLocation } from "react-router-dom";

export default function TopBar() {
  const location = useLocation();

  // map routes to titles
  const titles: Record<string, string> = {
    "/": "Home",
    "/home": "Home",
    "/damage_reports": "Damage Reports",
    "/clock_in": "Clock In",
    "/clock_out": "Clock Out",
    "/corrections": "Corrections",
    "/complains": "Complains",
    "/require": "Require",
    "/user_management": "User Management",
    "/create_memo": "Create Memo",
    "/batteries": "Batteries",
    "/asset_management": "Asset Management",
    "/rider_complaints": "Rider Complaints",
    "/profiles": "Profiles",
    "/income_approval": "Income Approval",
    "/cash_flow_statements": "Cash Flow Statements",
    "/polls": "Polls",
    "/poll_creation": "Create a Poll",
    "/footprints": "Footprints",
    "/restoration": "Restoration",
    "/human_resource": "Human Resource",
    "/incidences_and_accidents": "Incidences & Accidents",
    "/daily_reports": "Daily Reports",
    "/weekly_reports": "Weekly Reports",
    "/admin_and_analytics": "Admin & Analytics",
    "/chatrooms": "Chatrooms",
    "/my_profile": "Me",
  };

  const title = titles[location.pathname] || "Page";

  return (
    <div className="topBar" id="topBar">
        <svg className="wave" viewBox="0 0 1440 320" xmlns="http://www.w3.org/2000/svg">
            <path
            d="M0,256L11.4,240C22.9,224,46,192,69,192C91.4,192,114,224,137,234.7C160,245,183,235,206,213.3C228.6,192,251,160,274,149.3C297.1,139,320,149,343,181.3C365.7,213,389,267,411,282.7C434.3,299,457,277,480,250.7C502.9,224,526,192,549,181.3C571.4,171,594,181,617,208C640,235,663,277,686,256C708.6,235,731,149,754,122.7C777.1,96,800,128,823,165.3C845.7,203,869,245,891,224C914.3,203,937,117,960,112C982.9,107,1006,181,1029,197.3C1051.4,213,1074,171,1097,144C1120,117,1143,107,1166,133.3C1188.6,160,1211,224,1234,218.7C1257.1,213,1280,139,1303,133.3C1325.7,128,1349,192,1371,192C1394.3,192,1417,128,1429,96L1440,64L1440,320L1428.6,320C1417.1,320,1394,320,1371,320C1348.6,320,1326,320,1303,320C1280,320,1257,320,1234,320C1211.4,320,1189,320,1166,320C1142.9,320,1120,320,1097,320C1074.3,320,1051,320,1029,320C1005.7,320,983,320,960,320C937.1,320,914,320,891,320C868.6,320,846,320,823,320C800,320,777,320,754,320C731.4,320,709,320,686,320C662.9,320,640,320,617,320C594.3,320,571,320,549,320C525.7,320,503,320,480,320C457.1,320,434,320,411,320C388.6,320,366,320,343,320C320,320,297,320,274,320C251.4,320,229,320,206,320C182.9,320,160,320,137,320C114.3,320,91,320,69,320C45.7,320,23,320,11,320L0,320Z"
            fill-opacity="1"
            ></path>
        </svg>
        
        <svg onClick={() => {
              // document.getElementById("sideNavHost")!.classList.add("open");
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
            }
          }
          className="hamburger" width="64px" height="64px" viewBox="-9.6 -9.6 43.20 43.20"
          fill="none" xmlns="http://www.w3.org/2000/svg" stroke="#1C274C"><g id="SVGRepo_bgCarrier"
          stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path d="M4 6H20M4 12H14M4 18H9" stroke="#1C274C" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"></path> </g></svg>

        <div className="icon-container">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 512 512"
              stroke-width="0"
              fill="currentColor"
              stroke="currentColor"
              className="icon"
              >
            <path
                d="M256 48a208 208 0 1 1 0 416 208 208 0 1 1 0-416zm0 464A256 256 0 1 0 256 0a256 256 0 1 0 0 512zM369 209c9.4-9.4 9.4-24.6 0-33.9s-24.6-9.4-33.9 0l-111 111-47-47c-9.4-9.4-24.6-9.4-33.9 0s-9.4 24.6 0 33.9l64 64c9.4 9.4 24.6 9.4 33.9 0L369 209z"
            ></path>
            </svg>
        </div>


        <div className="message-text-container">
            <p className="message-text">BILLK MOTOLINK</p>
            <p className="sub-text"><span className="secondaryText">bml/</span>{title}</p>
        </div>
        <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 15 15"
            stroke-width="0"
            fill="none"
            stroke="currentColor"
            className="cross-icon"
            >
        </svg>

        <svg width="64px"
          onClick={() => {
                const topBarTinyMenu = document.getElementById("topBarTinyMenu");
                if (topBarTinyMenu) {
                  topBarTinyMenu.style.display = topBarTinyMenu.style.display == "flex" ? "none" : "flex";
                }
              }}
            height="64px" viewBox="-9.6 -9.6 43.20 43.20" fill="none" xmlns="http://www.w3.org/2000/svg" stroke="#1C274D" stroke-width="0.792"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round" stroke="#CCCCCC" stroke-width="0.768"></g><g id="SVGRepo_iconCarrier"> <g id="style=bulk"> <g id="profile"> <path id="vector (Stroke)" fill-rule="evenodd" clip-rule="evenodd" d="M6.75 6.5C6.75 3.6005 9.1005 1.25 12 1.25C14.8995 1.25 17.25 3.6005 17.25 6.5C17.25 9.3995 14.8995 11.75 12 11.75C9.1005 11.75 6.75 9.3995 6.75 6.5Z" fill="#1C274D"></path> <path id="rec (Stroke)" fill-rule="evenodd" clip-rule="evenodd" d="M4.25 18.5714C4.25 15.6325 6.63249 13.25 9.57143 13.25H14.4286C17.3675 13.25 19.75 15.6325 19.75 18.5714C19.75 20.8792 17.8792 22.75 15.5714 22.75H8.42857C6.12081 22.75 4.25 20.8792 4.25 18.5714Z" fill="#1C274D"></path> </g> </g> </g></svg>
    </div>
  );
}
