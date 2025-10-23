import toast, { Toaster } from "react-hot-toast";
import AlertDialog from "../assets/Dialog";
import logo from "../assets/logo2.png";
import { useState } from "react";
import { db } from "../assets/Firebase";
import { doc, runTransaction } from "firebase/firestore";

export default function Destinations() {
    const [openDestinationsDialog, setOpenDestinationsDialog] = useState(false);
    const [destinationName, setDestinationName] = useState<string | null>(null);

    const AddDestination = (e: React.FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        if (!destinationName || destinationName.trim() === "") {
            return toast("Enter a valid location name.", {
                icon: "❗",
                style: {
                    borderRadius: "10px",
                    background: "#fff",
                    color: "red",
                },
            });
        }
        setOpenDestinationsDialog(true);
    }
    const handleDestinationsConfirm = () => {
        setOpenDestinationsDialog(false);
        addDestination();
    }
    async function addDestination() {
        const generalRef = doc(db, "general", "general_variables");

        if (!destinationName) {
            return toast("Destination invalid.", {
                icon: "❗",
                style: {
                borderRadius: "10px",
                background: "#fff",
                color: "red",
                },
            });
        }

        try {
            // Wrap Firestore logic inside toast.promise
            await toast.promise(
            (async () => {
                await runTransaction(db, async (transaction) => {
                const snapshot = await transaction.get(generalRef);

                // Initialize structure if missing
                const currentData = snapshot.exists() ? snapshot.data() : {};
                const currentDestinations = Array.isArray(currentData.destinations)
                    ? currentData.destinations
                    : [];

                // Duplicate check (case-insensitive)
                if (
                    currentDestinations.some(
                    (d) => d.toLowerCase() === destinationName.toLowerCase()
                    )
                ) {
                    throw new Error("duplicate");
                }

                // Add new destination
                const updatedDestinations = [...currentDestinations, destinationName.toUpperCase()];

                // Write back to Firestore
                if (!snapshot.exists()) {
                    transaction.set(generalRef, { destinations: updatedDestinations });
                } else {
                    transaction.update(generalRef, { destinations: updatedDestinations });
                }
                });
            })(),
            {
                loading: "Adding destination...",
                success: <b>Destination added successfully.</b>,
                error: (err) =>
                err.message === "duplicate"
                    ? "Destination already exists."
                    : <b>Failed to add destination.</b>,
            }
            );
        } catch (error) {
            return toast(`Critical error: ${error}.`, {
                icon: "❗",
                style: {
                borderRadius: "10px",
                background: "#fff",
                color: "red",
                },
            });
        } finally {
            // Always executed, even on error or duplicate
            location.reload();
        }
    }

    const handleDestinationsClose = () => {
        setOpenDestinationsDialog(false);
    }
    return (
        <div className="clockouts-container">
            <div><Toaster /></div>
            <form className="form_container" onSubmit={AddDestination}>
                <div className="logo_container">
                <img className="logo" src={logo} alt="logo" width={150} height={150} />
                </div>
                <div className="title_container">
                <p className="title">Operations</p>
                <span className="subtitle">Add a viable location</span>
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

                        {/* location name */}
                        <tr>
                            <td><label className="input_label" htmlFor="locationName">Location name</label></td>
                            <input
                                type="text"
                                name="locationName"
                                id="locationName"
                                value={destinationName || ""}
                                onChange={(e) => setDestinationName(e.target.value)}
                                title="Location Name"/>
                        </tr>
                        </tbody>
                    </table>

                    <button title="Add Destination" type="submit" className="sign-in_btn" >
                        <span>Add Destination</span>
                    </button>

                </div>

                <div className="separator">
                <hr className="line" />
                <span className="note">Operation Facilitation</span>
                <hr className="line" />
                </div>
            </form>

            <AlertDialog
                open={openDestinationsDialog}
                title="Confirm action"
                description="Are you sure you want to add this location?"
                onConfirm={handleDestinationsConfirm}
                onClose={handleDestinationsClose}
                />
        </div>
    );
}
