import { Toaster } from "react-hot-toast";
import AlertDialog from "../assets/Dialog";
import { useState, useEffect } from "react";
import logo from "../assets/logo2.png";

export default function UserManagement() {

  const [openUserManagementDialog, setOpenUserManagementDialog] =  useState(false);
  const [fullName, setFullName] = useState<string | null>(null);
  const [selectedGender, setSelectedGender] = useState<string>("");

  const AddUser = (e: React.FormEvent<HTMLFormElement>) => {
      e.preventDefault();
      setOpenUserManagementDialog(true);
  };

  const handleUserManagementConfirm = () => {
      setOpenUserManagementDialog(false);
      // Add user logic here
  }
  const handleUserManagementClose = () => {
      setOpenUserManagementDialog(false);
  }
  
  return (
    <div className="clockouts-container">
      <div><Toaster /></div>
      <form className="form_container" onSubmit={AddUser}>
          <div className="logo_container">
          <img className="logo" src={logo} alt="logo" width={150} height={150} />
          </div>
          <div className="title_container">
          <p className="title">Assets</p>
          <span className="subtitle">Add a battery</span>
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

                  {/* battery name */}
                  <tr>
                      <td><label className="input_label" htmlFor="fullName">Full Name</label></td>
                      <input
                          type="text"
                          name="fullName"
                          id="fullName"
                          value={fullName || ""}
                          onChange={(e) => setFullName(e.target.value)}
                          title="Battery Number" />
                  </tr>

                  {/* location */}
                  <tr>
                    <td><label className="input_label" htmlFor="location">Gender</label></td>
                    <td>
                      <select
                            title="Select Gender"
                            className="styled-select"
                            value={selectedGender?.toString() ?? ""}
                            onChange={(e) => setSelectedGender(e.target.value)}
                            >
                            <option value="">Select location</option>
                            <option value="">Male</option>
                            <option value="">Female</option>
                          </select>
                    </td>
                  </tr>

                  </tbody>
              </table>

              <button title="Clock Out" type="submit" className="sign-in_btn" >
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
          open={openUserManagementDialog}
          title="Confirm action"
          description="Are you sure you want to add this bike?"
          onConfirm={handleUserManagementConfirm}
          onClose={handleUserManagementClose}
          />
    </div>
  );
}
