(() => {
  function fetchUsers() {
    fetch("/api/users")
      .then((res) => res.json())
      .then((users) => {
        const userList = document.getElementById("userList");
        userList.innerHTML = "";

        users.forEach((user) => {
          const li = document.createElement("li");
          li.innerHTML = `
            ${user.name} (${user.email}) - ${user.role}
            <button class="edit" data-id="${user.id}">Edit</button>
            <button class="delete" data-id="${user.id}">Delete</button>
          `;
          userList.appendChild(li);
        });
      })
      .catch((err) => {
        console.error("Error fetching users:", err);
      });
  }

  document.addEventListener("DOMContentLoaded", () => {
    // Initial fetch
    fetchUsers();

    // Add new user
    document
      .getElementById("addUserForm")
      .addEventListener("submit", (event) => {
        event.preventDefault();

        const name = document.getElementById("name").value;
        const email = document.getElementById("email").value;
        const role = document.getElementById("role").value;

        fetch("/api/users", {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({ name, email, role }),
        })
          .then((res) => res.json())
          .then((data) => {
            console.log("Success:", data);
            fetchUsers();
          })
          .catch((err) => {
            console.error("Error:", err);
          });
      });

    // Edit/Delete user
    document.getElementById("userList").addEventListener("click", (event) => {
      // Edit
      if (event.target.classList.contains("edit")) {
        const id = event.target.getAttribute("data-id");
        const newName = prompt("Enter new name:");
        const newEmail = prompt("Enter new email:");
        const newRole = prompt("Enter new role (User/Admin):");

        if (newName && newEmail && newRole) {
          fetch(`/api/users/${id}`, {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ name: newName, email: newEmail, role: newRole }),
          })
            .then((res) => res.json())
            .then((data) => {
              console.log("Updated:", data);
              fetchUsers();
            })
            .catch((err) => {
              console.error("Error:", err);
            });
        }
      }

      // Delete
      if (event.target.classList.contains("delete")) {
        const id = event.target.getAttribute("data-id");

        if (confirm("Are you sure you want to delete this user?")) {
          fetch(`/api/users/${id}`, {
            method: "DELETE",
          })
            .then((res) => res.json())
            .then((data) => {
              console.log("Deleted:", data);
              fetchUsers();
            })
            .catch((err) => {
              console.error("Error:", err);
            });
        }
      }
    });
  });
})();
