// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@mapprotocol/mos/contracts/interface/IMOSV3.sol";
import "@mapprotocol/mos/contracts/interface/IMapoExecutor.sol";

abstract contract MapoExecutor is Ownable, IMapoExecutor {
    uint256 public constant MESSAGE_TYPE_MESSAGE = 0;
    uint256 public constant MESSAGE_TYPE_CALLDATE = 1;

    uint256 public constant gasLimitMin = 21000;
    uint256 public constant gasLimitMax = 10000000;

    IMOSV3 public mos;
    address public feeToken;
    mapping(uint256 => bytes) public trustedList;

    event SetTrustedAddress(uint256 toChainId, bytes toAddress);
    event SetFeeToken(address _feeToken);
    event SetMosAddress(address _mos);

    constructor(address _mosAddress) {
        require(_mosAddress != address(0), "MapoExecutor: invalid mos address");
        mos = IMOSV3(_mosAddress);
    }

    function mapoExecute(
        uint256 _fromChain,
        uint256 _toChain,
        bytes calldata _fromAddress,
        bytes32 _orderId,
        bytes calldata _message
    ) external virtual override returns(bytes memory newMessage){
        require(_msgSender() == address(mos), "MapoExecutor: invalid mos caller");

        bytes memory tempFromAddress = trustedList[_fromChain];

        require(_fromAddress.length == tempFromAddress.length && tempFromAddress.length > 0 && keccak256(_fromAddress) == keccak256(tempFromAddress),
            "MapoExecutor: invalid source chain address");

        newMessage = _execute(_fromChain, _toChain, _fromAddress, _orderId, _message);
    }

    function _execute(
        uint256 _fromChain,
        uint256 _toChain,
        bytes memory _fromAddress,
        bytes32 _orderId,
        bytes memory _message
    ) internal virtual returns(bytes memory);

    function _mosTransferOut(
        uint256 _toChain,
        uint256 _toType,
        bytes memory _payload,
        uint256 _gasLimit
    )internal virtual returns(bytes32) {
        bytes memory tempFromAddress = trustedList[_toChain];
        require(tempFromAddress.length > 0, "MapoExecutor: invalid remote trust address");

        bytes memory messageDataBytes;
        if (_toType == MESSAGE_TYPE_MESSAGE) {
            messageDataBytes = abi.encode(false, IMOSV3.MessageType.MESSAGE, tempFromAddress, _payload, _gasLimit, 0);
        } else if(_toType == MESSAGE_TYPE_CALLDATE) {
            messageDataBytes = abi.encode(false, IMOSV3.MessageType.CALLDATA, tempFromAddress, _payload, _gasLimit, 0);
        } else {
            require(false, "MapoExecutor: invalid message type");
        }

        (uint256 fee,) = mos.getMessageFee(_toChain, feeToken, _gasLimit);

        if (feeToken == address(0)) {
            return mos.transferOut{value:fee}(_toChain, messageDataBytes, feeToken);
        } else {
            SafeERC20.safeApprove(IERC20(feeToken), address(mos), fee);
            return mos.transferOut(_toChain, messageDataBytes, feeToken);
        }
    }

    function _getMessageFee(uint256 _toChain, uint256 _gasLimit) internal view returns(address token, uint256 amount) {
        (uint256 fee,) = mos.getMessageFee(_toChain, feeToken, _gasLimit);

        return (feeToken, fee);
    }


    function getTrustedAddress(uint256 _toChainId) external view returns(bytes memory){
        return trustedList[_toChainId];
    }


    function setTrustedAddress(uint256 _toChainId,bytes memory _toAddress) external onlyOwner {
        trustedList[_toChainId] = _toAddress;
        emit SetTrustedAddress(_toChainId, _toAddress);
    }


    function setFeeToken(address _feeToken) external onlyOwner {
        feeToken = _feeToken;
        emit SetFeeToken(_feeToken);
    }

    function setMosAddress(address _mos) external onlyOwner {
        require(_mos != address(0),"MapoExecutor: mos address cannot be a address(0)");
        mos = IMOSV3(_mos);
        emit SetMosAddress(_mos);
    }

}
