// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

interface IVerifier {
    /// @notice Verify the proof to create an account
    /// @notice Verifies email from a user that contains `accountSalt` in the email header
    ///         where `walletSalt = `hash(fromAddress, accountSalt)`
    /// @param emailDomain The domain of the user's email address
    /// @param dkimPublicKeyHash The hash of the DKIM public key of `emailDomain`
    /// @param emailNullifier The nullifier computed for the email
    /// @param emailTimestamp The timestamp of the email
    /// @param walletSalt Wallet used to create the account (hash of emailAddr and accountSalt)
    /// @param psiPoint PSI point of the user for the relayer
    /// @param proof Proof of email with above constraints
    function verifyAccountCreationProof(
        string memory emailDomain,
        bytes32 dkimPublicKeyHash,
        bytes32 emailNullifier,
        uint256 emailTimestamp,
        bytes32 walletSalt,
        bytes memory psiPoint,
        bytes memory proof
    ) external view returns (bool);

    /// @notice Verify the proof of email from user - used to verify EmailOp
    /// @notice Verify that relayer received an email where:
    ///         sender's email address domain is `emailDomain`,
    ///         sender's email address and relayer randmness derives `emailAddrPointer`,
    ///         is DKIM signed by public key whose hash is `dkimPublicKeyHash`,
    ///         the subject is same as `maskedSubject` with email address masked (if any),
    ///         and email address in subject is used to derive `recipientEmailAddrCommit`
    /// @param emailDomain The domain of the user's email address
    /// @param dkimPublicKeyHash The hash of the DKIM public key of `emailDomain`
    /// @param emailNullifier The nullifier computed for the email
    /// @param timestamp The timestamp of the email
    /// @param maskedSubject The subject of the email with (any) email address masked
    /// @param walletSalt The walletSalt used to derive user's account address - hash(emailAddress, accountSalt)
    /// @param hasEmailRecipient Whether the email subject has a recipient (email address)
    /// @param recipientEmailAddrCommit The hash of recipeint's email address (from subject) and a randomness
    /// @dev `emailAddrPointer`, `dkimPublicKeyHash` should be the values previously stored in the contract
    function verifyEmailOpProof(
        string memory emailDomain,
        bytes32 dkimPublicKeyHash,
        uint256 timestamp,
        bytes32 emailNullifier,
        string memory maskedSubject,
        bytes32 walletSalt,
        bool hasEmailRecipient,
        bytes32 recipientEmailAddrCommit,
        bytes memory proof
    ) external view returns (bool);

    /// @notice Verify the proof to claim and unclaimed to a recipient account
    /// @notice This verify that same email address is used in `recipientEmailAddrPointer` and `recipientEmailAddrCommit`
    /// @param recipientEmailAddrCommit The hash(emailAddress, randomness) where randomness was set by sender and passed to recipient relayer
    /// @param recipientWalletSalt Wallet salt for the recipient (claimer)
    /// @param proof ZK proof of the circuit
    function verifyClaimFundProof(
        bytes32 recipientEmailAddrCommit,
        bytes32 recipientWalletSalt,
        bytes memory proof
    ) external view returns (bool);
}
