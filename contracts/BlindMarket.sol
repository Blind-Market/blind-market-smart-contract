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
        address indexed buyer,
        address indexed seller,
        uint256 tokenId,
        uint256 price,
        uint256 usedBLI
    );

    // Event for finish request.
    event FinishPurchaseRequest(
        address indexed buyer,
        address indexed seller,
        uint256 tokenId,
        uint256 price,
        uint256 usedBLI
    );

    // Event for cancel request.
    event CancelPurchaseRequest(
        address indexed buyer,
        address indexed seller,
        uint256 tokenId
    );

    // 거버넌스 토큰
    uint256 public constant BLI = 0;

    // 등급별 수수료 비율
    uint256 public NoobFeeRatio; // 0.15
    uint256 public RookieFeeRatio; // 0.13
    uint256 public MemberFeeRatio; // 0.11
    uint256 public BronzeFeeRatio; // 0.09
    uint256 public SilverFeeRatio; // 0.0
    uint256 public GoldFeeRatio; // 0.05
    uint256 public PlatinumFeeRatio; // 0.03
    uint256 public DiamondFeeRatio; // 0.01

    // 수수료 수익 총계 -> 컨트랙트가 가지고 있는 수수료
    uint256 private FeeRevenues;

    constructor(
        // 등급별 수수료 비율
        uint256 _noob_fee_ratio, // 0.10
        uint256 _rookie_fee_ratio, // 0.9
        uint256 _member_fee_ratio, // 0.8
        uint256 _bronze_fee_ratio, // 0.7
        uint256 _silver_fee_ratio, // 0.6
        uint256 _gold_fee_ratio, // 0.5
        uint256 _platinum_fee_ratio, // 0.4
        uint256 _diamond_fee_ratio // 0.3
    ) ERC1155("http://BlindMarket.xyz/{id}.json") {
        // 등급별 수수료 비율
        NoobFeeRatio = _noob_fee_ratio; // 0.10
        RookieFeeRatio = _rookie_fee_ratio; // 0.9
        MemberFeeRatio = _member_fee_ratio; // 0.8
        BronzeFeeRatio = _bronze_fee_ratio; // 0.7
        SilverFeeRatio = _silver_fee_ratio; // 0.6
        GoldFeeRatio = _gold_fee_ratio; // 0.5
        PlatinumFeeRatio = _platinum_fee_ratio; // 0.4
        DiamondFeeRatio = _diamond_fee_ratio; // 0.3

        _tokenIdCounter.increment();
        FeeRevenues = 0;
    }

    // 유저 등급 enum
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

    // 거래 상태
    enum Phase {
        invalid,
        pending,
        shipping,
        done,
        canceled
    }

    // 유저 정보를 담기 위한 구조체
    struct UserData {
        string nickname;
        uint256 gradePoint;
        Grade grade;
    }

    // 거래 별 상태 저장을 위한 구조체
    struct Request {
        uint256 tokenId;
        uint256 usedBLI;
        uint256 price;
        string buyer;
        address buyerAddress;
        string seller;
        address sellerAddress;
        Phase phase;
    }

    // NFT 토큰 id별 Lock 상태
    mapping(uint256 => bool) MutexLockStatus;

    // 유저 주소와 유저 정보 구조체가 매핑
    mapping(address => UserData) UserInfo;

    // 구매한 유저 닉네임과 거래 별 상태 저장을 위한 구조체가 매핑
    mapping(uint256 => Request) Trade;

    // 유저 닉네임과 전체 거래 내역이 매핑
    mapping(string => Request[]) TradeLogTable;

    mapping(uint256 => string) private tokenURIs;

    // NFT 토큰이 Lock되어 있는지 검사
    modifier isLocked(uint256 tokenId) {
        require(MutexLockStatus[tokenId] == true, "This token was locked");

        _;
    }

    function _setURI(uint256 tokenId, string memory tokenURI) internal {
        tokenURIs[tokenId] = tokenURI;
        emit URI(uri(tokenId), tokenId);
    }

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

    // 컨트랙트가 호출자에게 승인받았는지 확인
    modifier isApproved() {
        require(
            isApprovedForAll(msg.sender, address(this)) == true,
            "Caller have to approve this contract address managing asset"
        );

        _;
    }

    // 지갑 소유자 또는 컨트랙트 관리자인지 확인
    modifier walletOwnerOrAdmin(address user) {
        require(
            msg.sender == user || msg.sender == owner(),
            "Only owner of contract or owner of wallet can see wallet information"
        );

        _;
    }

    function mintNFT(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyOwner {
        _mint(account, id, amount, data);
    }

    // NFT Token 발행
    function mintProduct(string memory uri) public isApproved {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        mintNFT(msg.sender, tokenId, 1, "");
        _setURI(tokenId, uri);
    }

    function estimateAmountOfBLI(address user, uint256 tokenId)
        internal
        view
        isApproved
        returns (uint256)
    {
        return
            Trade[tokenId].price / getRatioByGrade(UserInfo[user].grade) / 1000;
    }

    // 거래 금액에 비례해서 거버넌스 토큰 발행
    function mintBlindToken(address user, uint256 amount)
        private
        onlyOwner
        isApproved
    {
        mintNFT(user, BLI, amount, "");
    }

    function getRatioByGrade(Grade grade)
        public
        view
        isApproved
        returns (uint256)
    {
        if (grade == Grade.noob) {
            return NoobFeeRatio;
        } else if (grade == Grade.rookie) {
            return RookieFeeRatio;
        } else if (grade == Grade.member) {
            return MemberFeeRatio;
        } else if (grade == Grade.bronze) {
            return BronzeFeeRatio;
        } else if (grade == Grade.silver) {
            return SilverFeeRatio;
        } else if (grade == Grade.gold) {
            return GoldFeeRatio;
        } else if (grade == Grade.platinum) {
            return PlatinumFeeRatio;
        } else if (grade == Grade.diamond) {
            return DiamondFeeRatio;
        }
        return NoobFeeRatio;
    }

    // 수수료 측정 함수
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

        // Sender must be seller.
        require(
            keccak256(bytes(UserInfo[msg.sender].nickname)) ==
                keccak256(bytes(Trade[tokenId].seller)),
            "Sender must be seller."
        );

        Grade _sellerGrade = UserInfo[msg.sender].grade;
        uint256 _feeRatio = getRatioByGrade(_sellerGrade);

        return Trade[tokenId].price * _feeRatio;
    }

    // 회원가입 시 유저의 정보를 테이블에 추가하는 함수
    function setUserInfo(string memory nickname) public isApproved {
        require(UserInfo[msg.sender].grade == Grade.invalid);

        UserInfo[msg.sender].nickname = nickname;
        UserInfo[msg.sender].grade = Grade.noob;
    }

    // 유저의 등급을 업데이트하는 함수
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

        if (UserInfo[user].gradePoint > 2000001) {
            UserInfo[msg.sender].grade = Grade.diamond;
        } else if (UserInfo[user].gradePoint > 1000001) {
            UserInfo[msg.sender].grade = Grade.platinum;
        } else if (UserInfo[msg.sender].gradePoint > 500000) {
            UserInfo[msg.sender].grade = Grade.gold;
        } else if (UserInfo[msg.sender].gradePoint > 200000) {
            UserInfo[msg.sender].grade = Grade.silver;
        } else if (UserInfo[msg.sender].gradePoint > 100000) {
            UserInfo[msg.sender].grade = Grade.bronze;
        } else if (UserInfo[msg.sender].gradePoint > 10000) {
            UserInfo[msg.sender].grade = Grade.member;
        } else if (UserInfo[msg.sender].gradePoint > 2000) {
            UserInfo[msg.sender].grade = Grade.rookie;
        }
    }

    // 유저의 닉네임을 업데이트하는 함수
    function updateUserNickname(string memory nickname)
        public
        walletOwnerOrAdmin(msg.sender)
    {
        UserInfo[msg.sender].nickname = nickname;
    }

    // 유저 정보 조회
    function showUserInfo() public view isApproved returns (UserData memory) {
        return UserInfo[msg.sender];
    }

    // 거래 정보 조회
    function showTradeInfo(uint256 tokenId)
        public
        view
        isApproved
        returns (Request memory)
    {
        return Trade[tokenId];
    }

    // 유저의 거래 기록 조회
    function showTradeLog() public view isApproved returns (Request[] memory) {
        return TradeLogTable[UserInfo[msg.sender].nickname];
    }

    // 구매 단계 (1) : NFT Token을 잠그고 Pending 상태로 바꿔줌
    function turnIntoPending(
        uint256 tokenId,
        uint256 price,
        string memory seller,
        address sellerAddress
    ) public isApproved returns (bool) {
        // Mutex Lock
        Lock(tokenId);

        // Buyer Nickname
        string memory buyer = UserInfo[msg.sender].nickname;

        // Push new request.
        Trade[tokenId] = Request(
            tokenId,
            0,
            price,
            buyer,
            msg.sender,
            seller,
            sellerAddress,
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
        uint256 usedBLI
    ) public isApproved returns (bool) {
        // Buyer Nickname
        string memory _seller = UserInfo[msg.sender].nickname;
        string memory _buyer = UserInfo[Trade[tokenId].buyerAddress].nickname;

        // Only the request in pending phase can be shipping phase.
        require(Trade[tokenId].phase == Phase.pending);

        // Sender's nickname should be same with the nickname which involved with the request.
        require(
            keccak256(bytes(Trade[tokenId].seller)) == keccak256(bytes(_seller))
        );

        // Inputed BLI must be more than 0
        require(usedBLI >= 0);

        // Inputed BLI must be less than fee
        uint256 _fee = estimateFee(tokenId);
        require(usedBLI <= _fee);

        // Change phase
        Trade[tokenId].phase = Phase.shipping;

        // Set BLI
        Trade[tokenId].usedBLI = usedBLI;

        TradeLogTable[_buyer][index].phase = Phase.shipping;
        TradeLogTable[_seller][index].phase = Phase.shipping;
        return true;
    }

    // 구매 단계 (3) : 배송 완료시 거래를 Done 상태로 바꿔줌
    function turnIntoDone(uint256 tokenId, uint256 index)
        public
        payable
        isApproved
        returns (bool)
    {
        require(Trade[tokenId].phase == Phase.shipping);

        require(
            keccak256(bytes(UserInfo[msg.sender].nickname)) ==
                keccak256(bytes(Trade[tokenId].buyer))
        );

        // Change phase
        Trade[tokenId].phase = Phase.done;

        // Seller nickname
        string memory _seller = Trade[tokenId].seller;

        // estimateFee
        uint256 _fee = estimateFee(tokenId);

        // Get fee
        FeeRevenues += _fee;

        // Transfer fee to smart contract
        payable(address(this)).transfer(_fee);

        // Transfer price to seller
        payable(Trade[tokenId].sellerAddress).transfer(
            Trade[tokenId].price - _fee
        );

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

        emit FinishPurchaseRequest(
            Trade[tokenId].buyerAddress,
            Trade[tokenId].sellerAddress,
            tokenId,
            Trade[tokenId].price,
            Trade[tokenId].usedBLI
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
            keccak256(bytes(Trade[tokenId].seller)) ==
                keccak256(bytes(UserInfo[msg.sender].nickname)) ||
                keccak256(bytes(Trade[tokenId].buyer)) ==
                keccak256(bytes(UserInfo[msg.sender].nickname))
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
