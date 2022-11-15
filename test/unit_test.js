const {
	time,
	loadFixture,
} = require("@nomicfoundation/hardhat-network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");
const hre = require("hardhat");
const { upgrades, ethers } = require("hardhat");
const { isPrivateIdentifier } = require("typescript");

async function beforeTest() {
	const [owner, user1, user2] = await hre.ethers.getSigners();
	const BlindMarket = await hre.ethers.getContractFactory("BlindMarket");
	const blindMarket = await upgrades.deployProxy(BlindMarket);
	await blindMarket.deployed();
	return { BlindMarket, blindMarket, owner, user1, user2 };
}

async function setUserInfo(blindMarket, addr, nickname) {
	await blindMarket.connect(addr).setUserInfo(nickname);
}

async function setApprovalForAll(blindMarket, addr) {
	return await blindMarket
		.connect(addr)
		.setApprovalForAll(blindMarket.address, true);
}

describe("BlindMarket", function () {
	it("Deployment Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);
	});

	it("SetApprovalForAll Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);

		const ownerRes = await blindMarket
			.connect(owner)
			.setApprovalForAll(blindMarket.address, true);
		const user1Res = await blindMarket
			.connect(user1)
			.setApprovalForAll(blindMarket.address, true);
		const user2Res = await blindMarket
			.connect(user2)
			.setApprovalForAll(blindMarket.address, true);

		expect(
			await blindMarket.isApprovedForAll(owner.address, blindMarket.address)
		).to.equal(true);
		expect(
			await blindMarket.isApprovedForAll(user1.address, blindMarket.address)
		).to.equal(true);
		expect(
			await blindMarket.isApprovedForAll(user2.address, blindMarket.address)
		).to.equal(true);
	});

	it("setUserInfo Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);

		await setApprovalForAll(blindMarket, owner);
		await setApprovalForAll(blindMarket, user1);
		await setApprovalForAll(blindMarket, user2);

		await setUserInfo(blindMarket, owner, "owner");
		await setUserInfo(blindMarket, user1, "user1");
		await setUserInfo(blindMarket, user2, "user2");

		expect((await blindMarket.connect(owner).showUserInfo()).nickname).to.equal(
			"owner"
		);
		expect((await blindMarket.connect(user1).showUserInfo()).nickname).to.equal(
			"user1"
		);
		expect((await blindMarket.connect(user2).showUserInfo()).nickname).to.equal(
			"user2"
		);
	});

	it("mintProduct Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);
		await setApprovalForAll(blindMarket, user1);
		await setUserInfo(blindMarket, user1, "user1");
		await blindMarket.connect(user1).mintProduct("https://www.naver.com");
		await blindMarket.connect(user1).mintProduct("https://www.google.com");
		await blindMarket.connect(user1).mintProduct("https://www.yahoo.com");

		expect(await blindMarket.getTokenURI(0)).to.equal("https://www.naver.com");
		expect(await blindMarket.getTokenURI(1)).to.equal("https://www.google.com");
		expect(await blindMarket.getTokenURI(2)).to.equal("https://www.yahoo.com");
	});

	it("TurnIntoPending Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);
		await setApprovalForAll(blindMarket, owner);
		await setApprovalForAll(blindMarket, user1);
		await setUserInfo(blindMarket, owner, "owner");
		await setUserInfo(blindMarket, user1, "user1");
		await blindMarket.connect(owner).mintProduct("https://www.naver.com");

		await blindMarket
			.connect(user1)
			.turnIntoPending(0, 10000, "owner", owner.address, {
				value: 10000,
			});

		expect(await owner.getBalance()).not.equal(await user2.getBalance());
		expect(await user1.getBalance()).not.equal(await user2.getBalance());

		expect((await blindMarket.showTradeInfo(0)).phase).to.equal(2);
		expect((await blindMarket.showTradeInfo(0)).buyerAddress).to.equal(
			user1.address
		);
		expect((await blindMarket.showTradeInfo(0)).sellerAddress).to.equal(
			owner.address
		);
	});

	it("TurnIntoShipping Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);
		await setApprovalForAll(blindMarket, owner);
		await setApprovalForAll(blindMarket, user1);
		await setUserInfo(blindMarket, owner, "owner");
		await setUserInfo(blindMarket, user1, "user1");
		await blindMarket.connect(owner).mintProduct("https://www.naver.com");

		await blindMarket
			.connect(user1)
			.turnIntoPending(0, 10000, "owner", owner.address, {
				value: 10000,
			});

		await blindMarket.connect(owner).turnIntoShipping(0, 0, 0);

		expect((await blindMarket.showTradeInfo(0)).phase).to.equal(3);
		expect((await blindMarket.showTradeInfo(0)).buyerAddress).to.equal(
			user1.address
		);
		expect((await blindMarket.showTradeInfo(0)).sellerAddress).to.equal(
			owner.address
		);
	});
	it("TurnIntoDone Test", async function () {
		const { BlindMarket, blindMarket, owner, user1, user2 } = await loadFixture(
			beforeTest
		);
		await setApprovalForAll(blindMarket, owner);
		await setApprovalForAll(blindMarket, user1);
		await setUserInfo(blindMarket, owner, "owner");
		await setUserInfo(blindMarket, user1, "user1");
		await blindMarket.connect(owner).mintProduct("https://www.naver.com");

		await blindMarket
			.connect(user1)
			.turnIntoPending(0, 10000, "owner", owner.address, {
				value: 10000,
			});

		await blindMarket.connect(owner).turnIntoShipping(0, 0, 0);

		const beforeOwner = await owner.getBalance();
		await blindMarket.connect(user1).turnIntoDone(0, 0);

		expect((await blindMarket.showTradeInfo(0)).phase).to.equal(4);
		expect((await blindMarket.showTradeInfo(0)).buyerAddress).to.equal(
			user1.address
		);
		expect((await blindMarket.showTradeInfo(0)).sellerAddress).to.equal(
			owner.address
		);

		const afterOwner = await owner.getBalance();

		expect(BigInt(afterOwner) - BigInt(beforeOwner)).to.equal(9000);
	});

	// it("TurnIntoCancel Test");
});
