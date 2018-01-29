pragma solidity ^0.4.17;
contract CryptoPlaceMarket {
    address owner;
    string public standard = "CryptoPlace";
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint private constant TOTAL_PIXELS = 1000000;
    uint private constant INITIAL_PIXEL_PRICE = 1 finney;
    uint private constant COST_MULTIPLIER = 1; // This will be divided by 10 e.g. 1 / 10, 2 / 10
    uint private constant OWNER_CUT = 100; // This will be divided by 10000 to get the actual cut
    uint public nextPixelIndexToAssign = 0;

    bool public pixelsInitialized = false;
    //uint public pixelsRemainingToAssign = 0;

    struct Pixel {
        uint pixelIndex;
        address seller;
        uint cost;
        string color;
    }
    // Mapping with the owner address of each pixel
    mapping (uint => address) public ownerOf;
    // Mapping with the pixel balance of each address
    mapping (address => uint256) public balanceOf;
    // Mapping of a pixel index to its owner, cost to purchase, and current color
    mapping (uint => Pixel) public pixelInfo;
    // Mapping of an address to a pending balance of wei for withdrawal
    mapping (address => uint) public pendingWithdrawals;
    // Assign for first time pixel assignment.
    event Assign(address indexed to, uint256 pixelIndex);
    event Transfer(address indexed from, address indexed to, uint256 pixelIndex);
    event Purchase(uint indexed pixelIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event Update(uint indexed pixelIndex, uint cost, string color);
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    modifier sellerOnly(uint pixelIndex) {
        require(ownerOf[pixelIndex] == msg.sender);
        _;
    }
    modifier preInit() {
        require(pixelsInitialized != true);
        _;
    }
    modifier postInit() {
        require(pixelsInitialized == true);
        _;
    }
    modifier validIndex(uint pixelIndex) {
        require(pixelIndex < TOTAL_PIXELS);
        _;
    }

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CryptoPlaceMarket() public payable {
        balanceOf[msg.sender] = TOTAL_PIXELS;
        owner = msg.sender;
        totalSupply = TOTAL_PIXELS;
        //pixelsRemainingToAssign = TOTAL_PIXELS;
        name = "CRYPTOPLACE";
        symbol = "₽";
        decimals = 0;
    }

    function setInitialOwner(address to, uint pixelIndex) public onlyOwner preInit validIndex(pixelIndex) {
        if (ownerOf[pixelIndex] != to) {
            if (ownerOf[pixelIndex] != address(0)) {
                balanceOf[ownerOf[pixelIndex]]--;
            }
            ownerOf[pixelIndex] = to;
            balanceOf[to]++;
            Assign(to, pixelIndex);
        }
    }

    function setInitialOwners(address[] addresses, uint[] indices) public onlyOwner {
        uint n = addresses.length;
        for (uint i = 0; i < n; i++) {
            setInitialOwner(addresses[i], indices[i]);
        }
    }
    /* Function for contract owner to call once initialization of owners is done. Allows pixel transfers/sales to begin */
    function pixelInitializationComplete() public onlyOwner {
        pixelsInitialized = true;
    }

    /* Transfer ownership of a pixel to another user without requiring payment */
    function transfer(address to, uint pixelIndex) public postInit validIndex(pixelIndex) sellerOnly(pixelIndex) {
        require(to != address(0));
        ownerOf[pixelIndex] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, pixelIndex);
    }
    //TODO: Add fee structure? Reduce what seller gets by 1%?
    function buyPixel(uint pixelIndex, string color) public payable postInit validIndex(pixelIndex) {
        // Set seller and cost with condition for if this is the first time this pixel is sold
        Pixel memory pixel = pixelInfo[pixelIndex];
        address pixelSeller;
        uint pixelCost;
        if (pixel.seller == address(0)) {
            pixelSeller = owner;
            pixelCost = INITIAL_PIXEL_PRICE;
        } else {
            pixelSeller = pixel.seller;
            pixelCost = pixel.cost;
        }
        //TODO:: Restrict payment to equal cost? Put extra in withdrawal balance maybe?    
        require(msg.value >= pixelCost);
        // Set ownership to buyer, update balance of seller and buyer
        ownerOf[pixelIndex] = msg.sender;
        balanceOf[pixelSeller]--;
        balanceOf[msg.sender]++;
        // Refund any excess sent to senders widthrawls
        if (msg.value > pixelCost) {
            pendingWithdrawals[msg.sender] += (msg.value - pixelCost);
        }
        // Calculate cut and add to owners pending withdrawls
        uint256 ownerCut = pixelCost * (OWNER_CUT / 10000);
        pendingWithdrawals[owner] += ownerCut;
        // Add sale proceeds to seller's account for withdrawal
        pendingWithdrawals[pixelSeller] += (pixelCost - ownerCut);
        // Update pixel with new owner, new price and new color
        pixelInfo[pixelIndex] = Pixel(pixelIndex, msg.sender, (pixelCost * (COST_MULTIPLIER / 10)) + pixelCost, color);
        Transfer(pixelSeller, msg.sender, pixelIndex);
        Purchase(pixelIndex, msg.value, pixelSeller, msg.sender);
        Update(pixelIndex, pixelInfo[pixelIndex].cost, color);
    }
    /* Function for pixel seller to update price (only price reductions are allowed) */
    function updatePixel(uint pixelIndex, uint price) public postInit validIndex(pixelIndex) sellerOnly(pixelIndex) {
        require(price < pixelInfo[pixelIndex].cost);

        pixelInfo[pixelIndex].cost = price;
        Update(pixelIndex, price, pixelInfo[pixelIndex].color);
    }
    /* Function for pixel seller to update pixel color */
    function updatePixel(uint pixelIndex, string color) public postInit validIndex(pixelIndex) sellerOnly(pixelIndex) {
        require(keccak256(color) != keccak256(pixelInfo[pixelIndex].color));
        pixelInfo[pixelIndex].color = color;
        Update(pixelIndex, pixelInfo[pixelIndex].cost, color);
    }
    /* Function for pixel seller to update pixel price and color */
    function updatePixel(uint pixelIndex, string color, uint price) public postInit validIndex(pixelIndex) sellerOnly(pixelIndex) {
        require(keccak256(color) != keccak256(pixelInfo[pixelIndex].color));
        require(price < pixelInfo[pixelIndex].cost);

        pixelInfo[pixelIndex].color = color;
        pixelInfo[pixelIndex].cost = price;
        Update(pixelIndex, price, color);
    }
    function withdraw() public postInit {
        require(pixelsInitialized == true);
        uint amount = pendingWithdrawals[msg.sender];
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

}