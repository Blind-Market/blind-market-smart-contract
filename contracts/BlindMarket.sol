// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BLIND is ERC1155, Ownable, ERC1155Burnable, ERC1155Supply {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;

    // Event for deposit
    event PurchaseRequest(
        // uint128 price,
        // uint128 usedBLI,
        uint256 tokenId,
        address indexed buyer,
        address indexed seller
    );

    // Event for finish request.
    event FinishPurchaseRequest(
        // uint128 price,
        // uint128 usedBLI,
        uint256 tokenId,
        address indexed buyer,
        address indexed seller
    );

    // Event for cancel request.
    event CancelPurchaseRequest(
        uint256 tokenId,
        address indexed buyer,
        address indexed seller
    );

    // Governance Token
    uint256 public constant BLI = 0;

    // Fee ratio for each user grade
    uint256 public constant NOOB_FEE_RATIO = 10;
    uint256 public constant ROOKIE_FEE_RATIO = 9;
    uint256 public constant MEMBER_FEE_RATIO = 8;
    uint256 public constant BRONZE_FEE_RATIO = 7;
    uint256 public constant SILVER_FEE_RATIO = 6;
    uint256 public constant GOLD_FEE_RATIO = 5;
    uint256 public constant PLATINUM_FEE_RATIO = 4;
    uint256 public constant DIAMOND_FEE_RATIO = 3;

    // Total fee revenue
    uint256 private FeeRevenues;

    constructor() ERC1155("http://BlindMarket.xyz/{id}.json") {
        _tokenIdCounter.increment();
        FeeRevenues = 0;
    }

    // Enum for user grade
    enum Grade {
        invalid,
        noob,
        rookie,
        member,
        bronze,
        silver,
        gold,
        platinum,
        diamond
    }

    // Enum for trade phase
    enum Phase {
        invalid,
        pending,
        shipping,
        done,
        canceled
    }

    // Struct for store user data
    struct UserData {
        uint256 gradePoint;
        string nickname;
        Grade grade;
    }

    // Struct for store user data
    struct Request {
        // uint128 usedBLI;
        // uint128 price;
        uint256 tokenId;
        bytes32 hash;
        string buyer;
        string seller;
        address payable buyerAddress;
        address payable sellerAddress;
        Phase phase;
    }

    // Lock status of each NFT Token for product
    mapping(uint256 => bool) MutexLockStatus;

    // Mapping for user address and user information
    mapping(address => UserData) UserInfo;

    // Mapping for tokenID and trade request
    mapping(uint256 => Request) Trade;

    // Mapping for user nickname and total trade history
    mapping(string => Request[]) TradeLogTable;

    // Mapping for tokenID and token URI
    mapping(uint256 => string) private tokenURIs;

    // Check if the token is locked.
    modifier isLocked(uint256 tokenId) {
        require(MutexLockStatus[tokenId] == true, "This token was locked");

        _;
    }

    // Set tokenURI
    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

    // get tokenURI
    function getTokenURI(uint256 tokenId) public view returns (string memory) {
        return tokenURIs[tokenId];
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }

    //  NFT token lock
    function Lock(uint256 tokenId) private {
        if (MutexLockStatus[tokenId] == true) return;
        MutexLockStatus[tokenId] = true;
    }

    // NFT token unlock
    function Unlock(uint256 tokenId) private {
        if (MutexLockStatus[tokenId] == false) return;
        MutexLockStatus[tokenId] = false;
    }

    // Check if msg.sender approved contract.
    modifier isApproved() {
        require(
            isApprovedForAll(msg.sender, address(this)) == true,
            "Caller have to approve this contract address managing asset"
        );

        _;
    }

    // Check if msg.sender is owner or same with user.
    modifier walletOwnerOrAdmin(address user) {
        require(
            msg.sender == user || msg.sender == owner(),
            "Only owner of contract or owner of wallet can see wallet information"
        );

        _;
    }

    // Mint NFT
    function mintNFT(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        _mint(account, id, amount, data);
    }

    // Mint NFT Token for product
    function mintProduct(string memory uri) public isApproved {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        mintNFT(msg.sender, tokenId, 1, "");
        _setURI(tokenId, uri);
    }

    // Estimate amount of Blind token by user grade and trade price.
    function estimateAmountOfBLI(address user, uint256 tokenId)
        public
        view
        isApproved
        returns (uint256)
    {
        uint128 price;
        decode(Trade[tokenId].hash);

        return (price * getRatioByGrade(UserInfo[user].grade)) / 100000;
        // return
        //     (Trade[tokenId].price * getRatioByGrade(UserInfo[user].grade)) /
        //     100000;
    }

    // Mint Blind token by user grade and trade price.
    function mintBlindToken(address user, uint256 amount)
        private
        onlyOwner
        isApproved
    {
        mintNFT(user, BLI, amount, "");
    }

    // Get fee ratio by user grade.
    function getRatioByGrade(Grade grade)
        public
        view
        isApproved
        returns (uint256)
    {
        if (grade == Grade.noob) {
            return NOOB_FEE_RATIO;
        } else if (grade == Grade.rookie) {
            return ROOKIE_FEE_RATIO;
        } else if (grade == Grade.member) {
            return MEMBER_FEE_RATIO;
        } else if (grade == Grade.bronze) {
            return BRONZE_FEE_RATIO;
        } else if (grade == Grade.silver) {
            return SILVER_FEE_RATIO;
        } else if (grade == Grade.gold) {
            return GOLD_FEE_RATIO;
        } else if (grade == Grade.platinum) {
            return PLATINUM_FEE_RATIO;
        } else if (grade == Grade.diamond) {
            return DIAMOND_FEE_RATIO;
        }
        return NOOB_FEE_RATIO;
    }

    // Estimate total fee
    function estimateFee(uint256 tokenId)
        public
        view
        isApproved
        walletOwnerOrAdmin(msg.sender)
        returns (uint256)
    {
        // Must exist in trade table.
        require(
            Trade[tokenId].phase != Phase.invalid,
            "Must exist in trade table"
        );

        Grade _sellerGrade = UserInfo[msg.sender].grade;
        uint256 _feeRatio = getRatioByGrade(_sellerGrade);

        (uint128 usedBLI, uint128 price) = decode(Trade[tokenId].hash);

        usedBLI = 0;

        return (price * _feeRatio) / 100;
        // return (Trade[tokenId].price * _feeRatio) / 100;
    }

    // Set user data into UserInfo storage.
    function setUserInfo(string memory nickname) public isApproved {
        require(UserInfo[msg.sender].grade == Grade.invalid);

        UserInfo[msg.sender].nickname = nickname;
        UserInfo[msg.sender].grade = Grade.noob;
    }

    // Update user grade.
    /*
        noob : 0~2,000
        rookie : 2,001~10,000
        member : 10,001 ~ 100,000
        bronze : 100,001 ~ 200,000
        silver : 200,001 ~ 500,000
        gold : 500,001 ~ 1,000,000
        platinum : 1,000,001 ~ 2,000,000
        diamond : 2,000,001 ~ 
    */
    function updateUserGrade(address user) internal {
        require(UserInfo[user].grade != Grade.invalid);

        uint256 gp = UserInfo[user].gradePoint;

        if (gp > 2000001) {
            UserInfo[msg.sender].grade = Grade.diamond;
        } else if (gp > 1000001) {
            UserInfo[msg.sender].grade = Grade.platinum;
        } else if (gp > 500000) {
            UserInfo[msg.sender].grade = Grade.gold;
        } else if (gp > 200000) {
            UserInfo[msg.sender].grade = Grade.silver;
        } else if (gp > 100000) {
            UserInfo[msg.sender].grade = Grade.bronze;
        } else if (gp > 10000) {
            UserInfo[msg.sender].grade = Grade.member;
        } else if (gp > 2000) {
            UserInfo[msg.sender].grade = Grade.rookie;
        }
    }

    // Update user nickname.
    function updateUserNickname(string memory nickname)
        public
        walletOwnerOrAdmin(msg.sender)
    {
        UserInfo[msg.sender].nickname = nickname;
    }

    // Show user information
    function showUserInfo() public view isApproved returns (UserData memory) {
        return UserInfo[msg.sender];
    }

    // Show trade information
    function showTradeInfo(uint256 tokenId)
        public
        view
        isApproved
        returns (Request memory)
    {
        return Trade[tokenId];
    }

    // Show trade history for user
    function showTradeLog() public view isApproved returns (Request[] memory) {
        return TradeLogTable[UserInfo[msg.sender].nickname];
    }

    // Encodes "usedBLI" and "price" as "bytes32 hash".
    function encode(uint128 _usedBLI, uint128 _price)
        internal
        pure
        returns (bytes32 x)
    {
        assembly {
            mstore(0x16, _price)
            mstore(0x0, _usedBLI)
            x := mload(0x16)
        }
    }

    // Decodes "bytes32 hash" to "usedBLI" and "price".
    function decode(bytes32 x)
        internal
        pure
        returns (uint128 usedBLI, uint128 price)
    {
        assembly {
            price := x
            mstore(0x16, x)
            usedBLI := mload(0)
        }
    }

    // 구매 단계 (1) : NFT Token을 잠그고 Pending 상태로 바꿔줌
    function turnIntoPending(
        uint256 tokenId,
        uint128 price,
        string memory seller,
        address sellerAddress
    ) public isApproved returns (bool) {
        // Mutex Lock
        Lock(tokenId);

        // Buyer Nickname
        string memory buyer = UserInfo[msg.sender].nickname;

        bytes32 _hash = encode(0, price);
        // Push new request.
        Trade[tokenId] = Request(
            0,
            // price,
            // tokenId,
            _hash,
            buyer,
            seller,
            payable(msg.sender),
            payable(sellerAddress),
            Phase.pending
        );

        TradeLogTable[buyer].push(Trade[tokenId]);
        TradeLogTable[seller].push(Trade[tokenId]);

        return true;
    }

    // 구매 단계 (2) : 판매 물품이 배송되고 있다는 Shipping 상태로 바꿔줌
    function turnIntoShipping(
        uint256 tokenId,
        uint256 index,
        uint128 usedBLI
    ) public isApproved returns (bool) {
        // Buyer Nickname
        string memory _seller = UserInfo[msg.sender].nickname;
        string memory _buyer = UserInfo[Trade[tokenId].buyerAddress].nickname;

        // Only the request in pending phase can be shipping phase.
        require(Trade[tokenId].phase == Phase.pending);

        // Sender's nickname should be same with the nickname which involved with the request.
        require(
            keccak256(abi.encodePacked(Trade[tokenId].seller)) ==
                keccak256(abi.encodePacked(_seller))
        );

        // Inputed BLI must be more than 0
        require(usedBLI >= 0);

        // Inputed BLI must be less than fee
        uint256 _fee = estimateFee(tokenId);
        require(usedBLI <= _fee);

        // Change phase
        Trade[tokenId].phase = Phase.shipping;

        (uint128 _usedBLI, uint128 price) = decode(Trade[tokenId].hash);

        _usedBLI = usedBLI;

        bytes32 hash = encode(usedBLI, price);

        // Set BLI
        Trade[tokenId].hash = hash;

        TradeLogTable[_buyer][index].phase = Phase.shipping;
        TradeLogTable[_seller][index].phase = Phase.shipping;

        safeTransferFrom(
            Trade[tokenId].sellerAddress,
            Trade[tokenId].buyerAddress,
            tokenId,
            1,
            ""
        );

        return true;
    }

    // 구매 단계 (3) : 배송 완료시 거래를 Done 상태로 바꿔줌
    function turnIntoDone(
        uint256 tokenId,
        uint256 index,
        address payable seller
    ) public payable isApproved returns (bool) {
        require(
            Trade[tokenId].phase == Phase.shipping,
            "The product is not arrived yet."
        );

        require(
            keccak256(abi.encodePacked(UserInfo[msg.sender].nickname)) ==
                keccak256(abi.encodePacked(Trade[tokenId].buyer)),
            "Caller is not the buyer."
        );

        // Change phase
        Trade[tokenId].phase = Phase.done;

        // Seller nickname
        string memory _seller = Trade[tokenId].seller;

        // estimateFee
        uint256 _fee = estimateFee(tokenId);

        // Get fee
        FeeRevenues += _fee;

        uint128 price;
        decode(Trade[tokenId].hash);

        // Transfer fee to smart contract
        payable(address(this)).transfer(_fee);

        // Transfer price to seller
        seller.transfer(price - _fee);

        // Update Phase
        TradeLogTable[UserInfo[msg.sender].nickname][index].phase = Phase.done;
        TradeLogTable[_seller][index].phase = Phase.done;

        // Mint Blind Token to buyer and seller
        uint256 AmountOfBuyer = estimateAmountOfBLI(
            Trade[tokenId].buyerAddress,
            tokenId
        );
        uint256 AmountOfSeller = estimateAmountOfBLI(
            Trade[tokenId].sellerAddress,
            tokenId
        );
        mintBlindToken(Trade[tokenId].buyerAddress, AmountOfBuyer);
        mintBlindToken(Trade[tokenId].sellerAddress, AmountOfSeller);

        // Set users grade point
        UserInfo[Trade[tokenId].sellerAddress].gradePoint += 1000;
        UserInfo[Trade[tokenId].buyerAddress].gradePoint += 1000;

        // Update users grade
        updateUserGrade(Trade[tokenId].sellerAddress);
        updateUserGrade(Trade[tokenId].buyerAddress);

        // safeTransferFrom(
        //     Trade[tokenId].sellerAddress,
        //     Trade[tokenId].buyerAddress,
        //     tokenId,
        //     1,
        //     ""
        // );

        emit FinishPurchaseRequest(
            tokenId,
            Trade[tokenId].buyerAddress,
            Trade[tokenId].sellerAddress
        );
        return true;
    }

    // 구매 취소 : 거래가 취소되어 상태를 Canceled 상태로 바꾸고 NFT 토큰은 unlock
    function turnIntoCancel(uint256 tokenId, uint256 index)
        public
        isApproved
        returns (bool)
    {
        require(Trade[tokenId].phase != Phase.invalid);

        require(
            keccak256(abi.encodePacked(Trade[tokenId].seller)) ==
                keccak256(abi.encodePacked(UserInfo[msg.sender].nickname)) ||
                keccak256(abi.encodePacked(Trade[tokenId].buyer)) ==
                keccak256(abi.encodePacked(UserInfo[msg.sender].nickname))
        );

        // Change phase
        Trade[tokenId].phase = Phase.invalid;

        // Seller nickname
        string memory _seller = Trade[tokenId].seller;
        string memory _buyer = Trade[tokenId].buyer;

        TradeLogTable[_buyer][index].phase = Phase.canceled;
        TradeLogTable[_seller][index].phase = Phase.canceled;

        // Unlock Token
        Unlock(tokenId);

        return true;
    }
}
