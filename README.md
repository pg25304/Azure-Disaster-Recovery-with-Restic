# Azure Disaster Recovery with Restic

**Infrastructure as Code • Encrypted Backups • Tested Recovery**

Practical disaster recovery implementation on Microsoft Azure using **Azure Bicep, Restic, Azure Blob Storage, Managed Identity and Azure RBAC**.

## Project Overview

I designed and implemented a practical disaster recovery (DR) solution in Microsoft Azure to test how a small Linux-based workload could be rebuilt after infrastructure loss and its application data recovered from an independent backup repository.

The project combines **Azure Bicep** for repeatable infrastructure deployment with **Restic 0.19.1** for encrypted, snapshot-based backup and recovery. Azure Blob Storage provides an independent backup repository separated from the virtual machine being protected.

The protected workload was a small web application data directory located at:

`/srv/app-data`

My recovery objectives were:

- **RTO:** 60 minutes
- **RPO:** 1 hour

RTO represents the maximum acceptable downtime, while RPO represents the maximum acceptable period of data loss (Microsoft, 2026a).

---

## Architecture

The environment was deployed in **Azure UK South**.

The infrastructure included:

| Component | Implementation | Purpose |
|---|---|---|
| Infrastructure as Code | Azure Bicep | Repeatable deployment and rebuild |
| Compute | Ubuntu 22.04 VM | Hosts protected application data |
| Backup | Restic 0.19.1 | Encrypted snapshot backup and restore |
| Backup target | Azure Blob Storage | Independent persistent repository |
| Storage resilience | Standard GZRS | Zone and geo-redundant durability |
| Authentication | User-assigned Managed Identity | Avoids storage keys on the VM |
| Authorization | Storage Blob Data Contributor | RBAC access to Blob data |
| Protected path | `/srv/app-data` | Application data recovered during DR |

A **user-assigned managed identity** allowed the rebuilt VM to authenticate to Azure Storage without embedding a storage account key in the recovery workflow.

The storage account used **geo-zone-redundant storage (GZRS)**. Microsoft documents that GZRS replicates data across availability zones in the primary region and asynchronously to a secondary geographic region (Microsoft, 2026b).

---

## Backup Strategy

Restic was installed on the Ubuntu VM and upgraded to version **0.19.1**.

The Restic repository was initialized inside the private Azure Blob container:

`restic-backups`

The repository password was kept separately and was not embedded in the Bicep source or published evidence.

The VM authenticated to Blob Storage through its managed identity and Azure RBAC.

The protected directory was:

`/srv/app-data`

A successful Restic snapshot was created with:

**Snapshot ID:** `bd699b68`  
**Timestamp:** `14:29:20 UTC – 21 September 2026`

The snapshot contained the application data required for recovery, including `index.html`.

Restic supports restoring selected or latest snapshots and provides repository integrity checking (Restic, 2026a; Restic, 2026b).

---

## Disaster Recovery Test

The simulated disaster represented **loss of the application server and its infrastructure**, rather than simply deleting an individual file.

The recovery therefore required both:

1. **Infrastructure reconstruction**
2. **Application-data restoration**

Azure Bicep was used to recreate the required infrastructure.

Azure Activity Log evidence recorded the VM create/update operation beginning at:

`15:00:53 UTC`

and succeeding at:

`15:01:00 UTC`

This represents approximately **7.5 seconds of Azure VM resource provisioning time**.

This measurement is **not the complete RTO**, because full recovery also required VM access, authentication, reconnection to the Restic repository, restoration and validation.

---

## Data Recovery

After rebuilding the VM, I:

1. Re-established access to the server.
2. Authenticated using the user-assigned managed identity.
3. Reconnected Restic to the persistent Azure Blob repository.
4. Located the available backup snapshot.
5. Restored the latest snapshot.
6. Verified the recovered application files.
7. Performed a Restic repository integrity check.

The restored data included:

`/srv/app-data/index.html`

Restic reported that **three files/directories (283 B)** were restored.

The recovered `index.html` was displayed directly on the rebuilt VM to verify that the expected application content had returned.

The restore followed Restic's documented snapshot recovery process (Restic, 2026a).

---

## Recovery Objectives and Results

| Metric | Target | Observed Evidence | Assessment |
|---|---|---|---|
| RPO | 1 hour | Latest recoverable snapshot: 14:29:20 UTC | Latest recovery point successfully restored |
| RTO | 60 minutes | Recovery underway by 14:52 UTC; restored data verified around 15:24–15:25 UTC | Recovery completed within the planned objective based on available evidence |
| VM provisioning | N/A | 15:00:53–15:01:00 UTC | Approximately 7.5 seconds; not the full RTO |

The recovery procedure successfully demonstrated that the Azure infrastructure could be recreated and that the existing Restic recovery point remained accessible from the rebuilt VM.

---

## Security and Resilience

The design avoided storing Azure Storage account keys on the VM.

Instead, it used:

- **User-assigned Managed Identity**
- **Azure RBAC**
- **Storage Blob Data Contributor**
- **Private Blob container**
- **Encrypted Restic repository**

The managed identity existed independently of the individual VM lifecycle. This was important because the compute resource could be destroyed and recreated while retaining an identity capable of accessing the backup repository.

The Restic repository was also independent of the protected compute workload. Losing the application VM therefore did not remove the recovery copy.

This approach is consistent with NIST contingency-planning guidance, which emphasizes recovery strategies, testing and maintaining recovery capability (Swanson et al., 2010).

---

## Recovery Validation

Recovery was not considered complete simply because the Restic restore command succeeded.

I also:

- Listed the restored files.
- Displayed `index.html`.
- Checked recovered file metadata.
- Verified the original file timestamp.
- Ran `restic check`.

The repository integrity check completed with:

`no errors were found`

Restic recommends repository checking as part of repository maintenance and integrity validation (Restic, 2026b).

---

## Cost and Resource Lifecycle

After completing the recovery test and collecting the required evidence, I deleted the dedicated Azure resource group.

This prevented unnecessary cloud expenditure and demonstrated appropriate cloud-resource lifecycle management.

---

## Limitations and Future Improvements

The project deliberately used a small static application workload rather than a transactional database.

Restic provided file-level recovery, so database-consistency mechanisms were outside the scope of this implementation.

Although **GZRS** improved storage durability, I did not perform an Azure regional failover. Therefore, this implementation should not be described as a tested multi-region application failover (Microsoft, 2026b; Microsoft, 2026c).

I have previously implemented a separate **Azure Failover and Load Balancing** project (April–May 2017), which explored Azure failover and service availability in greater depth:

**LinkedIn project:**  
https://www.linkedin.com/in/paymanghorbani/details/projects/

Future improvements could include:

- Automated Restic backup scheduling
- Automated RPO/RTO timestamp collection
- Application health checks
- Azure Key Vault for recovery credentials
- Transactional database recovery testing
- Regional failover testing
- Automated DR orchestration

---

## What This Project Demonstrates

- Azure disaster recovery architecture
- Infrastructure as Code with Azure Bicep
- Azure Blob Storage
- Restic backup and recovery
- User-assigned Managed Identity
- Azure RBAC
- Encrypted backup repositories
- RTO and RPO evaluation
- Infrastructure reconstruction
- Application-data restoration
- Recovery validation
- Cloud cost and resource lifecycle management

---

## Repository Structure

```text
Azure-Disaster-Recovery-with-Restic/
│
├── Infrastructure/
│   └── main.bicep
│
├── docs/
│   ├── architecture.png
│   └── DR-RUNBOOK.md
│
├── evidence/
│   ├── backup-snapshot.png
│   ├── restore-verification.png
│   └── teardown.png
│
└── README.md
