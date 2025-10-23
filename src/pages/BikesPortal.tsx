import toast, { Toaster } from "react-hot-toast";
import AlertDialog from "../assets/Dialog";
import logo from "../assets/logo2.png";
import { useState } from "react";
import { db } from "../assets/Firebase";
import { doc, setDoc, getDoc, updateDoc} from "firebase/firestore";

export default function BikesPortal() {
    const [openClockOutDialog, setOpenClockOutDialog] = useState(false);
    const [bikePlate, setBikePlate] = useState<string | null>(null);

    const AddBike = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        if (!bikePlate || bikePlate.trim() === "") {
            return toast("Enter a valid plate number.", {
                icon: "❗",
                style: {
                    borderRadius: "10px",
                    background: "#fff",
                    color: "red",
                },
            });
        }
        setOpenClockOutDialog(true);
    }

    const handleClockOutConfirm = () => {
        setOpenClockOutDialog(false);
        addBikeToFirestore();
    }
    async function addBikeToFirestore() {
        const bikesRef = doc(db, "general", "general_variables");

        const cleanPlate = bikePlate?.trim().toUpperCase();
        if (!cleanPlate) {
            return toast("Please enter a valid plate number.", {
                icon: "❗",
                style: {
                borderRadius: "10px",
                background: "#fff",
                color: "red",
                },
            });
        }

        return toast.promise(
            (async () => {
            // Step 1: Attempt to fetch the document
            const docSnap = await getDoc(bikesRef);

            // Step 2: Handle first-time initialization
            if (!docSnap.exists()) {
                await setDoc(bikesRef, {
                bikes: {
                    [cleanPlate]: {
                    isAssigned: false,
                    assignedRider: "None",
                    },
                },
                });
                return cleanPlate;
            }

            // Step 3: Get existing bikes
            const currentData = docSnap.data();
            const currentBikes = currentData?.bikes || {};

            // Step 4: Prevent duplicates
            if (Object.prototype.hasOwnProperty.call(currentBikes, cleanPlate)) {
                return toast("This bike already exists.", {
                    icon: "❗",
                    style: {
                    borderRadius: "10px",
                    background: "#fff",
                    color: "red",
                    },
                });
            }

            // Step 5: Merge new bike into existing map
            const updatedBikes = {
                ...currentBikes,
                [cleanPlate]: {
                isAssigned: false,
                assignedRider: "None",
                },
            };

            // Step 6: Update Firestore (guaranteed path now exists)
            await updateDoc(bikesRef, { bikes: updatedBikes });

            setBikePlate("")
            return cleanPlate;
            })(),
            {
                loading: "Adding bike...",
                success: (plate) => <b>Bike {plate} added successfully.</b>,
                error: (err) => <b>{err.message || "Failed to add bike."}</b>,
            }
        );
    }

    const handleClockOutClose = () => {
        setOpenClockOutDialog(false);
    }
    
    return (
        <div className="clockouts-container">
        <div><Toaster /></div>
        <form className="form_container" onSubmit={AddBike}>
            <div className="logo_container">
            <img className="logo" src={logo} alt="logo" width={150} height={150} />
            </div>
            <div className="title_container">
            <p className="title">Assets</p>
            <span className="subtitle">Add a bike</span>
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

                    {/* bike name */}
                    <tr>
                        <td><label className="input_label" htmlFor="bikeNumber">Bike plate number</label></td>
                        <input
                            type="text"
                            name="bikeNumber"
                            id="bikeNumber"
                            value={bikePlate || ""}
                            onChange={(e) => setBikePlate(e.target.value)}
                            title="Bike Plate Number"/>
                    </tr>

                    </tbody>
                </table>

                <button title="Add Bike" type="submit" className="sign-in_btn" >
                    <span>Add Bike</span>
                </button>

            </div>

            <div className="separator">
            <hr className="line" />
            <span className="note">Asset Management</span>
            <hr className="line" />
            </div>
        </form>

        <AlertDialog
            open={openClockOutDialog}
            title="Confirm action"
            description="Are you sure you want to add this bike?"
            onConfirm={handleClockOutConfirm}
            onClose={handleClockOutClose}
            />
        </div>
    );
}
