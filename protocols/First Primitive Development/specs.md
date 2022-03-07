# First Primitive Development
## Introduction
The First Primitive of a digitally native health system should be a way to represent an entity that is operating within a health system. The representation will be done on a ERC721 token. The token is transferrable, but loses it's "Verified" status upon transfer. 

*Note: HCP = Health Care Professional*

## Properties
The proposed entity struct should have the following properties:

1. Type of entity: Integer: HCP (which type?), non-HCP, health organization, non-health organization
2. healthID: String: If applicable, the identifier provided by the HCP's governing body. Allows for off-chain verification.
3. Governing body: String: If applicable, the governing body which provided the HCP ID.
4. Verified: Bool: Has the HCP been verfied by two other verified HCPs?
5. Auditor: Bool: Is this HCP trusted to verify and audit other HCPs?
6. Active: Bool: Is this HCP allowed to practice?
7. Minter: Bool: Can this HCP induct other HCPs onto the chain?
8. Reputation: Integer: The HCPs reputation on-chain.
9. Sponsor: Integer: takes the ID of the ERC721 that verified the HCP.

## Functions
The ERC721 contract will require the following functions:
### Mint 
@Notice: Creates a healthEntity struct at index[n]+1 ERC721
@Dev: Mints a new ERC721 with the specified parameters
@param: type: integer representing the type of entity. This corresponds with the entity type list, which must be hosted on Arweave
@param: healthID: string, lowercase, representing the healthcare ID provided by the governing body. No set format as no international standard
@param: governingBody: string, lowercase, representing the issuer of the healthcare ID - the governing body of health credentials in that territory. No standard format available.
@param: verified: boolean, true = has been verified by two other verified HCPs, false = has not been verified by two other HCPs.
@param: auditor: boolean, true = is auditor, false = is not an auditor
@param: active: boolean, true = can participate in health system, false = cannot participate in health system
@param: minter: boolean, true = can call mint function, false = cannot call mint function

Mint is called by a wallet holding an ERC721 healthEntity token that has the "minter" role enabled. A new mint is created with the fields of verified, auditor, active and minter set to false.

### Verify
@notice: sets the "verified" attribute of a target healthEntity as true, if it has been verified by another healthEntity
@dev: set "verified" to true and set the "sponsor" attribute of the target healthEntity as the ID of the function caller. 
@param: targetID: integer, this is the index that refers to the target healthEntity (the entity that gets verified). Require that ownedBy[targetID] cannot equal ownedBy[msg.sender].
@returns: boolean: true = success, false = unsuccessful

### Audit
@notice: this allows for the resetting of healthEntity details. Can only be called by healthDAO/ethics multisig 
@dev: targetID: integer, index of target healthEntity. This function allows for the resetting of type, healthID, governingBody, verified, auditor, active and minter attributes. It should only be used by the founder (if no DAO yet), or by the DAO (in emergency) or by the ethicsDAO multisig. It cannot be called on healthEntity ERC721s held by msg.sender
