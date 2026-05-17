✦ Here is a comprehensive directory of the seeded accounts and their roles for testing.

🔐 Global Credentials

- Password for ALL accounts: password123
- Status: All are ACTIVE unless marked as SUSPENDED.

---

👑 Administrators (React Admin Panel)
Used for governing users, approving finances, and monitoring the ledger.

┌───────────────┬────────────────────────┬──────────────────────────────────────────────────┐
│ Name │ Email │ Primary Use Case │
├───────────────┼────────────────────────┼──────────────────────────────────────────────────┤
│ Super Admin │ super@disasteraid.pk │ Full platform control & governance. │
│ Finance Admin │ finance@disasteraid.pk │ Specifically for Ledger and financial approvals. │
│ System Admin │ admin@disasteraid.pk │ Default seeded admin. │
└───────────────┴────────────────────────┴──────────────────────────────────────────────────┘

---

🏢 NGOs (React Admin Panel / Future NGO Portal)
Used for creating campaigns and requesting withdrawals.

┌─────────────────┬──────────────────────┬────────────────────────────────┐
│ Organization │ Email │ Wallet Balance │
├─────────────────┼──────────────────────┼────────────────────────────────┤
│ Red Cross PK │ contact@redcross.pk │ 500,000 PKR │
│ Edhi Foundation │ info@edhi.org │ 1,250,000 PKR │
│ Saylani Trust │ saylani@trust.pk │ 0 PKR (Zero Balance Edge Case) │
│ Al-Khidmat │ alkhidmat@service.pk │ 75,000 PKR │
│ Shadow NGO │ shadow@ngo.pk │ SUSPENDED (Login should fail) │
└─────────────────┴──────────────────────┴────────────────────────────────┘

---

👷 Volunteers (Flutter App)
Used for claiming tasks, uploading proof, and chatting with beneficiaries.

┌────────────────┬─────────────────────────────────────┬───────────────────────────────┐
│ Name │ Email │ Status / Notes │
├────────────────┼─────────────────────────────────────┼───────────────────────────────┤
│ Ahmed Khan │ ahmed@volunteer.pk │ Active (High Rating: 4.8) │
│ Sara Bibi │ sara@volunteer.pk │ Active (Perfect Rating: 5.0) │
│ John Doe │ john@volunteer.pk │ Active (Low Rating: 3.2) │
│ Idle Volunteer │ idle@volunteer.pk │ 0 completed tasks. │
│ Suspended Vol │ bad@volunteer.pk │ SUSPENDED (Login should fail) │
│ Volunteers 5-9 │ v5@volunteer.pk ... v9@volunteer.pk │ Standard active volunteers. │
└────────────────┴─────────────────────────────────────┴───────────────────────────────┘

---

🏥 Beneficiaries (Flutter App)
Used for requesting aid and coordinating with volunteers.

┌───────────────────┬─────────────────────────────┬─────────────────────────────────────────┐
│ Name │ Email │ Context │
├───────────────────┼─────────────────────────────┼─────────────────────────────────────────┤
│ Zia Flood Victim │ zia@needs.pk │ Has an active Flour Delivery task. │
│ Fatima Medical │ fatima@needs.pk │ Has an Urgent Insulin task in progress. │
│ Beneficiaries 3-5 │ b3@needs.pk ... b5@needs.pk │ Standard beneficiaries. │
└───────────────────┴─────────────────────────────┴─────────────────────────────────────────┘

---

💰 Donors (Flutter App)
Used for donating to campaigns and viewing history.

┌───────────────┬─────────────────────────────┬─────────────────────────────────────────────┐
│ Name │ Email │ History │
├───────────────┼─────────────────────────────┼─────────────────────────────────────────────┤
│ Whale Donor │ rich@donor.pk │ Multiple large donations (500k+ total). │
│ Micro Donor 1 │ m1@donor.pk │ Small change donation (10.50 PKR). │
│ Donors 3-9 │ d3@donor.pk ... d9@donor.pk │ Various donation states (Pending/Rejected). │
└───────────────┴─────────────────────────────┴─────────────────────────────────────────────┘

---

📋 Coordinators (Flutter App / Admin Panel)
Used for verifying field deliveries and assigned tasks.

┌───────────────┬─────────────┬───────────────────────────────────────────┐
│ Name │ Email │ Primary Use Case │
├───────────────┼─────────────┼───────────────────────────────────────────┤
│ Field Lead C1 │ c1@field.pk │ Assigned to coordinate active deliveries. │
│ Audit Lead C2 │ c2@field.pk │ Verifies task completion proof. │
└───────────────┴─────────────┴───────────────────────────────────────────┘

---

💡 Testing Scenarios Available:

1.  Financial Audit: Log in as finance@disasteraid.pk to see the Ledger populated with the Whale Donor's
    transactions.
2.  Task Flow: Log in as ahmed@volunteer.pk on Flutter to see the "Flour Delivery" task he has already
    SUBMITTED.
3.  Governance: Log in as super@disasteraid.pk to see bad@volunteer.pk already SUSPENDED in the User
    Management list.
4.  Campaign Stress: Check the "Emergency Cardiac Unit" campaign; it is intentionally Over-funded (Raised >
    Goal).
