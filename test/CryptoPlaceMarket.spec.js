var CryptoPlaceMarket = artifacts.require("CryptoPlaceMarket");
contract('CryptoPlaceMarket', (accounts) => {
    let instance;
    let owner;
    const Colors = Object.freeze({
        'xffffff': 0,
        'xe4e4e4': 1,
        'x888888': 2,
        'x222222': 3,
        'xffa7d1': 4,
        'xe50000': 5,
        'xe59500': 6,
        'xa06a42': 7,
        'xe5d900': 8,
        'x94e044': 9,
        'x02be01': 10,
        'x00d3dd': 11,
        'x0083c7': 12,
        'x0000ea': 13,
        'xcf6ee4': 14,
        'x820080': 15
    });
    
    beforeEach(async () => {
        owner = accounts[0];
        instance = await CryptoPlaceMarket.new();
    })
    it("shoud have an owner", async () => {
        let contractOwner = await instance.owner();
        assert.equal(contractOwner.toLowerCase(), owner.toLowerCase());
    })
    it("shoud initialize with a million pixel supply", async () => {
        let totalSupply = await instance.totalSupply.call();
        assert.equal(totalSupply.valueOf(), 1000000);
    })
    it("shoud initialize with a spacing pixel in the pixel array", async () => {
        // returns pixel as array [location, cost, color]
        let pixel = await instance.pixels.call(0);
        let purchased = await instance.getPurchasedPixelsCount.call();
        assert(purchased, 1);
        assert.equal(pixel[0], 0);
        assert.equal(pixel[1], 0);
        assert.equal(pixel[1], 0);
    })
    it("shoud allow initial ownership to be set before initialization", async () => {
        let initialOwnerAddress = await instance.ownerOf(0);
        await instance.setInitialOwner(accounts[1], 0);
        let balance = await instance.balanceOf(accounts[1])
        let ownerAddress = await instance.ownerOf(0);
        assert.equal(initialOwnerAddress, '0x0000000000000000000000000000000000000000');
        assert.equal(balance, 1);
        assert.equal(ownerAddress.toUpperCase(), accounts[1].toUpperCase());
    })

    it("shoud not allow for the purchase of pixels before initialization", async () => {
        let pixelsToPurchase = [0];
        let colorsForPixels = [2];
        try {
            await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 9000000000000000, from: accounts[1]});
        } catch (error) {
            assert.ok(error);
        }
    })

    it("shoud allow for the purchase of pixels based on location", async () => {
        let pixelsToPurchase = [0];
        let colorsForPixels = [2];
        await instance.pixelInitializationComplete({from: owner});
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 9000000000000000, from: accounts[1]});
        let balance = await instance.balanceOf(accounts[1]);
        assert.equal(balance, 1);
    })
    it("shoud credit the owner with the purchase price when a pixel is FIRST purchased", async () => {
        let pixelsToPurchase = [0];
        let colorsForPixels = [2];
        await instance.pixelInitializationComplete({from: owner});
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 9000000000000000, from: accounts[1]});
        let pendingBalance = await instance.pendingWithdrawals(owner);
        assert.equal(pendingBalance, 1000000000000000);
    })
    it("shoud credit the buyer with the excess wei sent when pixel is purchased", async () => {
        let pixelsToPurchase = [0];
        let colorsForPixels = [2];
        await instance.pixelInitializationComplete({from: owner});
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 9000000000000000, from: accounts[1]});
        let pendingBalance = await instance.pendingWithdrawals(accounts[1]);
        assert.equal(pendingBalance, 8000000000000000);
    })
    it("shoud credit the owner with the a fee when a pixel is purchased", async () => {
        let pixelsToPurchase = [0];
        let colorsForPixels = [2];
        await instance.pixelInitializationComplete({from: owner});
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 1000000000000000, from: accounts[1]});
        let pendingBalance = await instance.pendingWithdrawals(owner);
        assert.equal(pendingBalance, 1000000000000000);
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 1100000000000000, from: accounts[2]});
        pendingBalance = await instance.pendingWithdrawals(owner);
        assert.equal(pendingBalance, 1011000000000000);
    })
    it("shoud credit the seller with the a purchase price minus fee when their pixel is purchased", async () => {
        let pixelsToPurchase = [0];
        let colorsForPixels = [2];
        await instance.pixelInitializationComplete({from: owner});
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 1000000000000000, from: accounts[1]});
        await instance.buyPixels(pixelsToPurchase, colorsForPixels, {value: 1100000000000000, from: accounts[2]});
        let pendingBalance = await instance.pendingWithdrawals(accounts[1]);
        assert.equal(pendingBalance, 1089000000000000);
    })
})