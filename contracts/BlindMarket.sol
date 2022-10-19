// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract BLIND is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
	
	// Event for deposit
	event PurchaseRequest(address indexed buyer, address indexed seller, uint256 tokenId, uint256 price, uint256 usedBLI);

	// Event for finish request.
	event FinishPurchaseRequest(address indexed buyer, address indexed seller, uint256 tokenId, uint256 price, uint256 usedBLI);

	// Event for cancel request.
	event CancelPurchaseRequest(address indexed buyer, address indexed seller, uint256 tokenId);

	// 거버넌스 토큰
	uint256 public constant BLI = 0;

	// 등급별 수수료 비율
	uint256 public NoobFeeRatio;
	uint256 public RookieFeeRatio;
	uint256 public MemberFeeRatio;
	uint256 public BronzeFeeRatio;
	uint256 public SilverFeeRatio;
	uint256 public GoldFeeRatio;
	uint256 public PlatinumFeeRatio;
	uint256 public DiamondFeeRatio;

    constructor(
		// 등급별 수수료 비율
		uint256 _noob_fee_ratio,
		uint256 _rookie_fee_ratio,
		uint256 _member_fee_ratio,
		uint256 _bronze_fee_ratio,
		uint256 _silver_fee_ratio,
		uint256 _gold_fee_ratio,
		uint256 _platinum_fee_ratio,
		uint256 _diamond_fee_ratio
	) ERC721("BLIND", "BLI") {
		// 등급별 수수료 비율
		NoobFeeRatio = _noob_fee_ratio;
		RookieFeeRatio = _rookie_fee_ratio;
		MemberFeeRatio = _member_fee_ratio;
		BronzeFeeRatio = _bronze_fee_ratio;
		SilverFeeRatio = _silver_fee_ratio;
		GoldFeeRatio = _gold_fee_ratio;
		PlatinumFeeRatio = _platinum_fee_ratio;
		DiamondFeeRatio = _diamond_fee_ratio;

		_tokenIdCounter.increment();
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
        diamode
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
        Grade grade;
    }

    // 거래 별 상태 저장을 위한 구조체
	struct Request {
        uint256 tokenId;
		uint256 price;
		string buyer;
		string seller;
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

    // NFT 토큰이 Lock
	modifier isLocked(uint256 tokenId) {
		require(MutexLockStatus[tokenId] == true, "This token was locked");

		_;
	}

	function Lock(uint256 tokenId)
	private
	{
		if (MutexLockStatus[tokenId] == true)
			return;
		MutexLockStatus[tokenId] = true;
	}

    function Unlock(uint256 tokenId) 
    private 
    {
        if (MutexLockStatus[tokenId] == false)
            return;
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

    modifier isTokenOwner(uint256 tokenId) {
        address nftTokenOwner = ownerOf(tokenId);
        require(nftTokenOwner == msg.sender, 'caller is not nft token owner.');

        _;
    }

    function mintProduct(string memory uri)
	isApproved
    public 
    {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(msg.sender, tokenId);
        _setTokenURI(tokenId, uri);
    }

	function setUserInfo(string memory nickname)
	isApproved
	public
	{
		require(UserInfo[msg.sender].grade == Grade.invalid);

		UserInfo[msg.sender].nickname = nickname;
		UserInfo[msg.sender].grade = Grade.noob;
	}

	function updateUserGrade(Grade grade)
	public
	onlyOwner
	{
		require(grade != Grade.invalid);

		UserInfo[msg.sender].grade = grade;
	}

	function updateUserNickname(string memory nickname)
	public
	walletOwnerOrAdmin(msg.sender)
	{
		UserInfo[msg.sender].nickname = nickname;
	}

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage)
	isApproved
    isTokenOwner(tokenId)
	{
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

	function showUserInfo()
	public
	view
	isApproved
	returns (UserData memory)
	{
		return UserInfo[msg.sender];
	}

    function showTradeInfo(uint256 tokenId)
    public
    view
    isApproved
    returns (Request memory)
    {
        return Trade[tokenId];
    }

    function showTradeLog()
    public
    view
    isApproved
    returns (Request[] memory)
    {
        return TradeLogTable[UserInfo[msg.sender].nickname];
    }

	function turnIntoPending(uint256 tokenId, uint256 price, string memory seller)
	public
	isApproved
	returns (bool)
	{
		// Mutex Lock
		Lock(tokenId);

		// Buyer Nickname
		string memory _buyer = UserInfo[msg.sender].nickname;

		// Push new request. 
		Trade[tokenId] = Request(tokenId, price, _buyer, seller, Phase.pending);

		TradeLogTable[_buyer].push(Trade[tokenId]);
		TradeLogTable[seller].push(Trade[tokenId]);

        return true;
	}

	function turnIntoShipping(uint256 tokenId, uint256 index)
	public
	isApproved
	returns (bool)
	{
		// Buyer Nickname
		string memory _seller = UserInfo[msg.sender].nickname;

		// Only the request in pending phase can be shipping phase.
		require(Trade[tokenId].phase == Phase.pending);

		// Sender's nickname should be same with the nickname which involved with the request.
		require(keccak256(bytes(Trade[tokenId].seller)) == keccak256(bytes(_seller)));

		// Change phase
		Trade[tokenId].phase = Phase.shipping;

		TradeLogTable[UserInfo[msg.sender].nickname][index].phase = Phase.shipping;
		TradeLogTable[_seller][index].phase = Phase.shipping;
		return true;
	}

	function turnIntoDone(uint256 tokenId, uint256 index)
	public
	isApproved
	returns (bool)
	{
		require(Trade[tokenId].phase == Phase.shipping);

		require(keccak256(bytes(UserInfo[msg.sender].nickname)) == keccak256(bytes(Trade[tokenId].buyer)));

		// Change phase
		Trade[tokenId].phase = Phase.done;

		// Seller nickname
		string memory _seller = Trade[tokenId].seller;

		TradeLogTable[UserInfo[msg.sender].nickname][index].phase = Phase.done;
		TradeLogTable[_seller][index].phase = Phase.done;
		return true;
	}

	function turnIntoCancel(uint256 tokenId, uint256 index)
	public
	isApproved
	returns (bool)
	{
		require(Trade[tokenId].phase != Phase.invalid);

		require(
			keccak256(bytes(Trade[tokenId].seller)) == keccak256(bytes(UserInfo[msg.sender].nickname)) || 
			keccak256(bytes(Trade[tokenId].buyer)) == keccak256(bytes(UserInfo[msg.sender].nickname))
		);

		// Change phase
		Trade[tokenId].phase = Phase.canceled;

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