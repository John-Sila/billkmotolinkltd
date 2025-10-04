import logo from "../assets/logo2.png";
import { useEffect, useState } from "react";
import { fetchUser, type UserData } from "../services/userService";
import { getAuth, onAuthStateChanged } from "firebase/auth";
import PrimaryLoadingFragment from "../assets/PrimaryLoading";
import { Toaster } from 'react-hot-toast';
import toast from 'react-hot-toast';
import { db } from "../assets/Firebase";
import { doc, updateDoc, arrayUnion, Timestamp } from "firebase/firestore";
import AlertDialog from "../assets/Dialog";

export default function DamageReports() {
  const [user, setUser] = useState<UserData | null>(null);
  const [loading, setLoading] = useState(true);
  const [uid, setUid] = useState<string | null>(null);
  const [reportType, setReportType] = useState<string | null>(null);
  const [reportDescription, setReportDescription] = useState<string>("");
  const [latitude, setLatitude] = useState<number | null>(null);
  const [longitude, setLongitude] = useState<number | null>(null);
  const [openDialog, setOpenDialog] = useState(false);


    useEffect(() => {
      const auth = getAuth();
      const unsubscribe = onAuthStateChanged(auth, (firebaseUser) => {
        if (firebaseUser) {
          setUid(firebaseUser.uid);
          fetchLocation();
        } else {
          setUid(null);
          setLoading(false);
          }
      });

      return () => unsubscribe();
    }, []);
  
    useEffect(() => {
      if (!uid) return;
  
      async function loadUser() {
        const data = await fetchUser(uid);
        setUser(data);
        setLoading(false);
      }
  
      loadUser();
    }, [uid]);

    const fetchLocation = () => {
      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          const { latitude, longitude } = pos.coords;
          setLatitude(latitude);
          setLongitude(longitude);

          setLoading(false);
          },
          (err: any) => {
              setLoading(false);
              return toast(err,
                {
                  icon: '❗',
                  style: {
                    borderRadius: '10px',
                    background: '#fff',
                    color: 'red',
                  },
                }
              );
          }
      )
    }

    const submitDamageReport = async (e: React.FormEvent) => {
      e.preventDefault();
      const bikeName = (document.getElementById("bike_field") as HTMLInputElement).value;
      if (bikeName === "None") {
        return toast("You don't have a bike assigned to you.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      }
      if (!reportType || reportType === "") {
        return toast("Select a report type.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      }
      if (!reportDescription || reportDescription === "") {
        return toast("Describe your report.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      }
      if (!user?.userName || user.userName === "") {
        return toast("Your username lacks authenticity.",
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      }

      // we are good
      setOpenDialog(true);
      
    }


    const handleConfirm = async () => {
      setOpenDialog(false);
      const reportsRef = doc(db, "general", "general_variables");
      const bikeName = (document.getElementById("bike_field") as HTMLInputElement).value;

      const reportData = {
        username: user?.userName,
        reportType: reportType,
        reportDescription: reportDescription,
        involvedBike: bikeName,
        time: Timestamp.now(),
        location: {
          latitude: latitude,
          longitude: longitude,
        },
      };

      try {
        await toast.promise(
          updateDoc(reportsRef, {
            reports: arrayUnion(reportData),
          }),
          {
            loading: "Submitting damage report...",
            success: <b>Report submitted!</b>,
            error: <b>Could not submit report.</b>,
          }
        );
        setReportDescription("");
      } catch (err) {
        console.error("Error submitting damage report:", err);
        return toast(err as string,
          {
            icon: '❗',
            style: {
              borderRadius: '10px',
              background: '#fff',
              color: 'red',
            },
          }
        );
      }
    };

    const handleClose = () => {
      setOpenDialog(false);
    };

    if (loading) return <PrimaryLoadingFragment />;

  return (
    <div className="damage-reports-container">
      <div><Toaster/></div>
      <form className="form_container" onSubmit={submitDamageReport}>
        <div className="logo_container">
          <img className="logo" src={logo} alt="logo" width={150} height={150} />
        </div>
        <div className="title_container">
          <p className="title">Damage Reports</p>
          <span className="subtitle">Report all damages as soon as they occur.</span>
        </div>
        <br />
        <div className="input_container">
          <svg width="64px" height="64px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path fill-rule="evenodd" clip-rule="evenodd" d="M14.4672 2.0002C14.4105 1.9989 14.3551 2.00393 14.3018 2.01464C13.5511 1.99999 12.7218 2 11.8069 2L11.6932 2C10.7782 2 9.94895 1.99999 9.19825 2.01464C9.14488 2.00393 9.08952 1.9989 9.03282 2.0002C6.54819 2.05713 4.77756 2.27987 3.53716 3.52277L3.52979 3.53017L3.52277 3.53716C2.27987 4.77756 2.05712 6.54819 2.0002 9.03283C1.9989 9.08952 2.00393 9.14488 2.01464 9.19825C2.0127 9.29746 2.01102 9.39804 2.00956 9.5H3.75C4.99264 9.5 6 10.5074 6 11.75C6 12.9926 4.99264 14 3.75 14H2.00956C2.01102 14.102 2.0127 14.2026 2.01464 14.3018C2.00393 14.3552 1.9989 14.4105 2.0002 14.4672C2.05713 16.9518 2.27987 18.7224 3.52277 19.9628L3.52997 19.97L3.53716 19.9772C4.77756 21.2201 6.54818 21.4429 9.03283 21.4998C9.08952 21.5011 9.14488 21.4961 9.19825 21.4854C9.94894 21.5 10.7782 21.5 11.6931 21.5H11.8069C12.7218 21.5 13.5511 21.5 14.3018 21.4854C14.3552 21.4961 14.4105 21.5011 14.4672 21.4998C16.9518 21.4429 18.7224 21.2201 19.9628 19.9772L19.9699 19.9702L19.9772 19.9628C21.2201 18.7224 21.4429 16.9518 21.4998 14.4672C21.5011 14.4105 21.4961 14.3552 21.4854 14.3018C21.4873 14.2026 21.489 14.102 21.4904 14H19.75C18.5074 14 17.5 12.9926 17.5 11.75C17.5 10.5074 18.5074 9.5 19.75 9.5H21.4904C21.489 9.39804 21.4873 9.29746 21.4854 9.19825C21.4961 9.14488 21.5011 9.08952 21.4998 9.03283C21.4429 6.54819 21.2201 4.77756 19.9772 3.53716L19.9701 3.53001L19.9628 3.52277C18.7224 2.27987 16.9518 2.05713 14.4672 2.0002ZM7.75 7C7.33579 7 7 7.33579 7 7.75C7 8.16421 7.33579 8.5 7.75 8.5H11V15.75C11 16.1642 11.3358 16.5 11.75 16.5C12.1642 16.5 12.5 16.1642 12.5 15.75V8.5H15.75C16.1642 8.5 16.5 8.16421 16.5 7.75C16.5 7.33579 16.1642 7 15.75 7H7.75Z" fill="#1C274C"></path> <path d="M19 11.75C19 11.3358 19.3358 11 19.75 11H21.75C22.1642 11 22.5 11.3358 22.5 11.75C22.5 12.1642 22.1642 12.5 21.75 12.5H19.75C19.3358 12.5 19 12.1642 19 11.75Z" fill="#1C274C"></path> <path d="M1.75 11C1.33579 11 1 11.3358 1 11.75C1 12.1642 1.33579 12.5 1.75 12.5H3.75C4.16421 12.5 4.5 12.1642 4.5 11.75C4.5 11.3358 4.16421 11 3.75 11H1.75Z" fill="#1C274C"></path> </g></svg>
          <label className="input_label" htmlFor="bike_field">Bike</label>
          <input placeholder="" title="Involved bike" name="bike_field-name" type="text" value={user?.currentBike} className="input_field" id="bike_field" readOnly/>
        </div>

        {/* nature of accident */}
        <div className="input_container">
          <div className="radio-input">
            <p className="reportTypeText">Report Type</p>
            <hr />
            <label className="label" 
                onClick={() => setReportType("Mechanical Break-Down")}>
              <input
                type="radio"
                id="value-1"
                name="value-radio"
                value="value-1"
              />
              <p className="text">Mechanical Break-Down</p>
            </label>
            <label className="label" 
                onClick={() => setReportType("Police Arrest")}>
              <input type="radio" id="value-2" name="value-radio" value="value-2" />
              <p className="text">Police Arrest</p>
            </label>
            <label className="label"
                onClick={() => setReportType("Road Accident")}>
              <input type="radio" id="value-3" name="value-radio" value="value-3" />
              <p className="text">Road Accident</p>
            </label>
          </div>
        </div>

        <div className="input_container">
          <svg width="64px" height="64px" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g id="SVGRepo_bgCarrier" stroke-width="0"></g><g id="SVGRepo_tracerCarrier" stroke-linecap="round" stroke-linejoin="round"></g><g id="SVGRepo_iconCarrier"> <path fill-rule="evenodd" clip-rule="evenodd" d="M14.4672 2.0002C14.4105 1.9989 14.3551 2.00393 14.3018 2.01464C13.5511 1.99999 12.7218 2 11.8069 2L11.6932 2C10.7782 2 9.94895 1.99999 9.19825 2.01464C9.14488 2.00393 9.08952 1.9989 9.03282 2.0002C6.54819 2.05713 4.77756 2.27987 3.53716 3.52277L3.52979 3.53017L3.52277 3.53716C2.27987 4.77756 2.05712 6.54819 2.0002 9.03283C1.9989 9.08952 2.00393 9.14488 2.01464 9.19825C2.0127 9.29746 2.01102 9.39804 2.00956 9.5H3.75C4.99264 9.5 6 10.5074 6 11.75C6 12.9926 4.99264 14 3.75 14H2.00956C2.01102 14.102 2.0127 14.2026 2.01464 14.3018C2.00393 14.3552 1.9989 14.4105 2.0002 14.4672C2.05713 16.9518 2.27987 18.7224 3.52277 19.9628L3.52997 19.97L3.53716 19.9772C4.77756 21.2201 6.54818 21.4429 9.03283 21.4998C9.08952 21.5011 9.14488 21.4961 9.19825 21.4854C9.94894 21.5 10.7782 21.5 11.6931 21.5H11.8069C12.7218 21.5 13.5511 21.5 14.3018 21.4854C14.3552 21.4961 14.4105 21.5011 14.4672 21.4998C16.9518 21.4429 18.7224 21.2201 19.9628 19.9772L19.9699 19.9702L19.9772 19.9628C21.2201 18.7224 21.4429 16.9518 21.4998 14.4672C21.5011 14.4105 21.4961 14.3552 21.4854 14.3018C21.4873 14.2026 21.489 14.102 21.4904 14H19.75C18.5074 14 17.5 12.9926 17.5 11.75C17.5 10.5074 18.5074 9.5 19.75 9.5H21.4904C21.489 9.39804 21.4873 9.29746 21.4854 9.19825C21.4961 9.14488 21.5011 9.08952 21.4998 9.03283C21.4429 6.54819 21.2201 4.77756 19.9772 3.53716L19.9701 3.53001L19.9628 3.52277C18.7224 2.27987 16.9518 2.05713 14.4672 2.0002ZM7.75 7C7.33579 7 7 7.33579 7 7.75C7 8.16421 7.33579 8.5 7.75 8.5H11V15.75C11 16.1642 11.3358 16.5 11.75 16.5C12.1642 16.5 12.5 16.1642 12.5 15.75V8.5H15.75C16.1642 8.5 16.5 8.16421 16.5 7.75C16.5 7.33579 16.1642 7 15.75 7H7.75Z" fill="#1C274C"></path> <path d="M19 11.75C19 11.3358 19.3358 11 19.75 11H21.75C22.1642 11 22.5 11.3358 22.5 11.75C22.5 12.1642 22.1642 12.5 21.75 12.5H19.75C19.3358 12.5 19 12.1642 19 11.75Z" fill="#1C274C"></path> <path d="M1.75 11C1.33579 11 1 11.3358 1 11.75C1 12.1642 1.33579 12.5 1.75 12.5H3.75C4.16421 12.5 4.5 12.1642 4.5 11.75C4.5 11.3358 4.16421 11 3.75 11H1.75Z" fill="#1C274C"></path> </g></svg>
          <label className="input_label" htmlFor="description_field">Description</label>
          <textarea placeholder="Describe your report"
            value={reportDescription}
            onChange={(e: React.ChangeEvent<HTMLTextAreaElement>) =>
              setReportDescription(e.target.value)
            }
          title="Description" name="description_field-description" className="input_field" id="description_field" rows={4} />
        </div>



        <button title="Submit Damage Report" type="submit" className="sign-in_btn" >
          <span>Submit Damage Report</span>
        </button>

        <div className="separator">
          <hr className="line" />
          <span className="note">Quality Control</span>
          <hr className="line" />
        </div>
      </form>
      <AlertDialog
        open={openDialog}
        title="Confirm Submission"
        description="Are you sure you want to submit this damage report?"
        onConfirm={handleConfirm}
        onClose={handleClose}
      />
    </div>
  );
}
