// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "../interfaces/IVerifier.sol";

contract AllVerifiers is IVerifier {
    address public immutable accountCreationVerifier;
    address public immutable accountInitVerifier;
    address public immutable accountTransportVerifier;
    address public immutable claimVerifier;
    address public immutable emailSenderVerifier;

    uint constant public DOMAIN_BYTES = 255;
    uint constant public DOMAIN_FIELDS = 9;
    uint constant public SUBJECT_BYTES = 512;
    uint constant public SUBJECT_FIELDS = 17;

    constructor(
        address _accountCreationVerifier,
        address _accountInitVerifier,
        address _accountTransportVerifier,
        address _claimVerifier,
        address _emailSenderVerifier
    ) {
        accountCreationVerifier = _accountCreationVerifier;
        accountInitVerifier = _accountInitVerifier;
        accountTransportVerifier = _accountTransportVerifier;
        claimVerifier = _claimVerifier;
        emailSenderVerifier = _emailSenderVerifier;
    }
    


    /// @notice Verify the proof to create an account
    /// @notice Verify `emailAddrPointer`, `accountKeyCommit` and `walletSalt`
    ///         are calculated from the same `emailAddress`, `accountKey` and `relayerRandomness`
    /// @param relayerHash The hash of the relayer randomness
    /// @param emailAddrPointer The hash of the relayer randomness and email address
    /// @param accountKeyCommit The hash of the account key, email address and relayer randomness
    /// @param walletSalt The hash of the account key and 01
    /// @param psiPoint The psi point of the email address
    function verifyAccountCreationProof(
        bytes32 relayerHash,
        bytes32 emailAddrPointer,
        bytes32 accountKeyCommit,
        bytes32 walletSalt,
        bytes memory psiPoint,
        bytes memory proof
    ) external view returns (bool) {
        (uint[2] memory pA, uint[2][2] memory pB, uint[2] memory pC) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint[6] memory pubSignals;
        pubSignals[0] = uint(relayerHash);
        pubSignals[1] = uint(emailAddrPointer);
        pubSignals[2] = uint(accountKeyCommit);
        pubSignals[3] = uint(walletSalt);
        (uint x, uint y) = abi.decode(psiPoint, (uint, uint));
        pubSignals[4] = x;
        pubSignals[5] = y;
        (bool success, bytes memory result) = accountCreationVerifier.staticcall(abi.encodeWithSignature("verifyProof(uint[2],uint[2][2],uint[2],uint[6])", pA, pB, pC, pubSignals));
        require(success,"staticcall failed");
        return abi.decode(result, (bool));
    }

     /// @notice Verify the proof to initialize an account (reply to the invitation email)
    /// @notice This verify the relayer received an email from the user (with corresponding `emailAddrPointer`)
    ///         where `accountKey` (of corresponding `accountKeyCommit`) was used in `x-reply-to` header
    /// @param emailDomain The domain of the user's email address
    /// @param dkimPublicKeyHash The hash of the DKIM public key of `emailDomain`
    /// @param timestamp The timestamp of the email
    /// @param relayerHash The hash of the relayer randomness
    /// @param emailAddrPointer The hash of the relayer randomness and email address
    /// @param accountKeyCommit The hash of the account key, email address and relayer randomness
    /// @param emailNullifier The nullifier computed for the reply email
    /// @param proof Proof of email with above constraints
    /// @dev `accountKeyCommit`, `dkimPublicKeyHash` should be the values previously stored in the contract
    function verifyAccountInitializaionProof(
        string memory emailDomain,
        bytes32 dkimPublicKeyHash,
        uint256 timestamp,
        bytes32 relayerHash,
        bytes32 emailAddrPointer,
        bytes32 accountKeyCommit,
        bytes32 emailNullifier,
        bytes memory proof
    ) external view returns (bool) {
        (uint[2] memory pA, uint[2][2] memory pB, uint[2] memory pC) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint[15] memory pubSignals;
        uint[] memory domainFields = _packBytes2Fields(bytes(emailDomain), DOMAIN_BYTES);
        for(uint i=0; i<DOMAIN_FIELDS; i++) {
            pubSignals[i] = domainFields[i];
        }
        pubSignals[DOMAIN_FIELDS] = uint(dkimPublicKeyHash);
        pubSignals[DOMAIN_FIELDS+1] = uint(relayerHash);
        pubSignals[DOMAIN_FIELDS+2] = uint(emailNullifier);
        pubSignals[DOMAIN_FIELDS+3] = uint(emailAddrPointer);
        pubSignals[DOMAIN_FIELDS+4] = uint(accountKeyCommit);
        pubSignals[DOMAIN_FIELDS+5] = uint(timestamp);
        (bool success, bytes memory result) = accountInitVerifier.staticcall(abi.encodeWithSignature("verifyProof(uint[2],uint[2][2],uint[2],uint[15])", pA, pB, pC, pubSignals));
        require(success,"staticcall failed");
        return abi.decode(result, (bool));
    }

    /// @notice Verify the proof of email from user - used to verify EmailOp
    /// @notice Verify that relayer received an email where:
    ///         sender's email address domain is `emailDomain`,
    ///         sender's email address and relayer randmness derives `emailAddrPointer`,
    ///         is DKIM signed by public key whose hash is `dkimPublicKeyHash`,
    ///         the subject is same as `maskedSubject` with email address masked (if any),
    ///         and email address in subject is used to derive `recipientEmailAddrCommit`
    /// @param emailDomain The domain of the user's email address
    /// @param dkimPublicKeyHash The hash of the DKIM public key of `emailDomain`
    /// @param timestamp The timestamp of the email
    /// @param maskedSubject The subject of the email with (any) email address masked
    /// @param emailNullifier The nullifier computed for the email
    /// @param relayerHash The hash of the relayer randomness
    /// @param emailAddrPointer The hash of the relayer randomness and users's email address
    /// @param recipientEmailAddrCommit The hash of recipeint's email address (from subject) and a randomness
    /// @param hasEmailRecipient Whether the email subject has a recipient (email address)
    /// @dev `relayerHash`, `emailAddrPointer`, `dkimPublicKeyHash` should be the values previously stored in the contract
    function verifyEmailProof(
        string memory emailDomain,
        bytes32 dkimPublicKeyHash,
        uint256 timestamp,
        string memory maskedSubject,
        bytes32 emailNullifier,
        bytes32 relayerHash,
        bytes32 emailAddrPointer,
        bool hasEmailRecipient,
        bytes32 recipientEmailAddrCommit,
        bytes memory proof
    ) external view returns (bool) {
        (uint[2] memory pA, uint[2][2] memory pB, uint[2] memory pC) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint[33] memory pubSignals;
        uint[] memory subjectFields = _packBytes2Fields(bytes(maskedSubject), SUBJECT_BYTES);
        for(uint i=0; i<SUBJECT_FIELDS; i++) {
            pubSignals[i] = subjectFields[i];
        }
        uint[] memory domainFields = _packBytes2Fields(bytes(emailDomain), DOMAIN_BYTES);
        for(uint i=0; i<DOMAIN_FIELDS; i++) {
            pubSignals[SUBJECT_FIELDS+i] = domainFields[i];
        }
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS] = uint(dkimPublicKeyHash);
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS+1] = uint(relayerHash);
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS+2] = uint(emailNullifier);
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS+3] = uint(emailAddrPointer);
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS+4] = hasEmailRecipient ? 1 : 0;
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS+5] = uint(recipientEmailAddrCommit);
        pubSignals[SUBJECT_FIELDS+DOMAIN_FIELDS+6] = timestamp;
        (bool success, bytes memory result) = emailSenderVerifier.staticcall(abi.encodeWithSignature("verifyProof(uint[2],uint[2][2],uint[2],uint[33])", pA, pB, pC, pubSignals));
        require(success,"staticcall failed");
        return abi.decode(result, (bool));
    }

    /// @notice Verify the proof to claim and unclaimed to a recipient account
    /// @notice This verify that same email address is used in `recipientEmailAddrPointer` and `recipientEmailAddrCommit`
    /// @param recipientRelayerHash The hash of the relayer randomness
    /// @param recipientEmailAddrPointer The hash of the relayer randomness and recipient email address
    /// @param recipientEmailAddrCommit The hash(emailAddress, randomness) where randomness was set by sender and passed to recipient relayer
    /// @param proof ZK proof of the circuit
    function verifyClaimFundProof(
        bytes32 recipientRelayerHash,
        bytes32 recipientEmailAddrPointer,
        bytes32 recipientEmailAddrCommit,
        bytes memory proof
    ) external view returns (bool) {
        (uint[2] memory pA, uint[2][2] memory pB, uint[2] memory pC) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint[3] memory pubSignals;
        pubSignals[0] = uint(recipientRelayerHash);
        pubSignals[1] = uint(recipientEmailAddrPointer);
        pubSignals[2] = uint(recipientEmailAddrCommit);
        (bool success, bytes memory result) = claimVerifier.staticcall(abi.encodeWithSignature("verifyProof(uint[2],uint[2][2],uint[2],uint[3])", pA, pB, pC, pubSignals));
        require(success,"staticcall failed");
        return abi.decode(result, (bool));
    }

     /// @notice Verify the proof to transport account from one relayer to another
    /// @notice This will verify that relayer received an email from user with their account key somewhere in header
    ///         and the email is DKIM signed by the public key of `emailDomain` whose hash is `dkimPublicKeyHash`.
    ///         Also proved that the accountKeyCommit of old relayer with hash `oldRelayerRandHash` is same as `oldAccountKeyCommit`
    /// @param emailDomain The domain of the user's email address
    /// @param dkimPublicKeyHash The hash of the DKIM public key of `emailDomain`
    /// @param timestamp The timestamp of the email
    /// @param emailNullifier The nullifier computed for the email
    /// @param oldRelayerRandHash The hash of the old relayer randomness
    /// @param oldAccountKeyCommit The hash of the account key, email address and old relayer randomness
    /// @param proof Proof of email with above constraints
    function verifiyAccountTransportProof(
        string memory emailDomain,
        bytes32 dkimPublicKeyHash,
        uint256 timestamp,
        bytes32 emailNullifier,
        bytes32 oldRelayerRandHash,
        bytes32 oldAccountKeyCommit,
        bytes memory proof
    ) external view returns (bool) {
        (uint[2] memory pA, uint[2][2] memory pB, uint[2] memory pC) = abi.decode(proof, (uint[2], uint[2][2], uint[2]));
        uint[15] memory pubSignals;
        uint[] memory domainFields = _packBytes2Fields(bytes(emailDomain), DOMAIN_BYTES);
        for(uint i=0; i<DOMAIN_FIELDS; i++) {
            pubSignals[i] = domainFields[i];
        }
        pubSignals[DOMAIN_FIELDS] = uint(dkimPublicKeyHash);
        pubSignals[DOMAIN_FIELDS+1] = uint(emailNullifier);
        pubSignals[DOMAIN_FIELDS+2] = uint(oldAccountKeyCommit);
        pubSignals[DOMAIN_FIELDS+3] = uint(timestamp);
        pubSignals[DOMAIN_FIELDS+4] = uint(oldRelayerRandHash);
        (bool success, bytes memory result) = accountTransportVerifier.staticcall(abi.encodeWithSignature("verifyProof(uint[2],uint[2][2],uint[2],uint[14])", pA, pB, pC, pubSignals));
        require(success,"staticcall failed");
        return abi.decode(result, (bool));
    }

    function _packBytes2Fields(bytes memory _bytes, uint _paddedSize) public pure returns (uint[] memory) {
        uint remain = _paddedSize % 31;
        uint numFields = (_paddedSize - remain) / 31;
        if(remain > 0) {
            numFields += 1;
        }
        uint[] memory fields = new uint[](numFields);
        uint idx = 0;
        uint byteVal = 0;
        for(uint i=0; i<numFields; i++) {
            for(uint j=0; j<31; j++) {
                idx = i*31 + j;
                if(idx >= _paddedSize) {
                    break;
                } 
                if(idx >= _bytes.length) {
                    byteVal = 0;
                } else {
                    byteVal = uint(uint8(_bytes[idx]));
                }
                if (j == 0) {
                    fields[i] = byteVal;
                } else {
                    fields[i] += (byteVal << (8*j));
                }
            }
        }
        return fields;
    }
}