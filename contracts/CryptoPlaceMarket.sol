pragma solidity ^0.4.17;
contract CryptoPlaceMarket {
    address public owner;
    string public standard = "CryptoPlace";
    string public name;
    string public symbol;
    uint8 public decimals;
    uint256 public totalSupply;
    uint256 private constant TOTAL_PIXELS = 1000000;
    uint public constant INITIAL_PIXEL_PRICE = 1000000000000000;
    uint8 private constant COST_MULTIPLIER_PERCENT = 10;
    uint private constant OWNER_CUT_PERCENT = 1;
    enum ColorChoice { 
        xffffff, // 0 White
        xe4e4e4, // 1 Light Grey
        x888888, // 2 Dark Grey
        x222222, // 3 Black
        xffa7d1, // 4 Pink
        xe50000, // 5 Red
        xe59500, // 6 Orange
        xa06a42, // 7 Brown
        xe5d900, // 8 Yellow
        x94e044, // 9 Light Green
        x02be01, // 10 Green
        x00d3dd, // 12 Cyan
        x0083c7, // 13 Light Blue
        x0000ea, // 14 Blue
        xcf6ee4, // 15 Magenta
        x820080  // 16 Purple
    }
    ColorChoice public constant INITIAL_PIXEL_COLOR = ColorChoice.xffffff; 
    bool public pixelsInitialized = false;

    struct Pixel {
        uint256 location;
        uint256 cost;
        ColorChoice color;
    }
    // Mapping with the owner address of each pixel by location
    mapping (uint256 => address) public ownerOf;
    // Mapping with the pixel balance of each address
    mapping (address => uint256) public balanceOf;
    
    // Unordered Array of all owned pixels
    Pixel[] public pixels;
    // Mapping of a pixel location to it's index in the pixel array. There is no pixel at 0, so if it returns 0 it is
    // Currently in it's initial state (has not been purchased by anyone)
    mapping (uint256 => uint256) public pixelLocationToIndex;
    // Mapping of an address to a pending balance of wei for withdrawal
    mapping (address => uint) public pendingWithdrawals;
    // Assign for first time pixel assignment.
    event Assign(address indexed to, uint256 pixelIndex);
    event Transfer(address indexed from, address indexed to, uint256 pixelIndex);
    event Purchase(uint indexed pixelIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event Update(uint indexed pixelIndex, uint cost, ColorChoice color);
    
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
    modifier validLocation(uint256 location) {
        require(location < TOTAL_PIXELS);
        _;
    }
    modifier validColor(uint8 colorIndex) {
        require(uint8(ColorChoice.x820080) >= colorIndex);
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
        // Set 0 index pixel to pad out other pixel indexes. This is so we know if the locations => index is set or not
        // If the mapping returns an index of 0 we know it isn't set since there is no real pixel set at 0
        pixels.push(Pixel(0, 0, ColorChoice.xffffff));
    }
    function setInitialOwner(address to, uint pixelLocation) public onlyOwner preInit validLocation(pixelLocation) {
        if (ownerOf[pixelLocation] != to) {
            if (ownerOf[pixelLocation] != address(0)) {
                balanceOf[ownerOf[pixelLocation]]--;
            }
            ownerOf[pixelLocation] = to;
            balanceOf[to]++;
            Assign(to, pixelLocation);
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
    function transfer(address to, uint pixelLocation) public postInit validLocation(pixelLocation) sellerOnly(pixelLocation) {
        require(to != address(0));
        ownerOf[pixelLocation] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, pixelLocation);
    }
    function getPurchasedPixelsCount() public view returns(uint256) {
        return pixels.length;
    }
    function getPixel(uint256 pixelIndex) public validLocation(pixelIndex) view returns(uint256, uint256, ColorChoice) {
        return (pixels[pixelIndex].location, pixels[pixelIndex].cost, pixels[pixelIndex].color);
    }
    /* Buy one or more pixels and set the color of the pixels */
    function buyPixels(uint256[] pixelLocations, uint8[] colorIndicies) public payable postInit {
        uint256 totalCost = 0;
        uint256 x;
        // Totals cost of all pixels and confirm pixel locations and colors are valid
        for (x = 0; x < pixelLocations.length; x++) {
            uint256 pixelLocation = pixelLocations[x];
            require(pixelLocation < TOTAL_PIXELS);
            require(uint8(ColorChoice.x820080) >= colorIndicies[x]);
            // Get array index of pixel if it has previously been set. If not it will return 0
            uint256 pixelIndex = pixelLocationToIndex[pixelLocation];
            totalCost += (pixelIndex > 0) ? pixels[pixelIndex].cost : INITIAL_PIXEL_PRICE;
        }
        require(totalCost <= msg.value);
        // Refund any excess sent to senders widthrawals
        if (msg.value > totalCost) {
            pendingWithdrawals[msg.sender] += (msg.value - totalCost);
        }
        // Buy each pixel
        for (x = 0; x < pixelLocations.length; x++) {
            buyPixel(pixelLocations[x], colorIndicies[x]);
        }
    }
    /* Finalize purchase by transferring ownership then updating pixel and withrawal balances */
    function buyPixel(uint256 pixelLocation, uint8 colorIndex) private {
        // Set seller and cost with condition for if this is the first time this pixel is sold
        uint256 pixelIndex = pixelLocationToIndex[pixelLocation];
        // Pixel memory pixel = pixels[pixelIndex];
        address pixelSeller;
        uint256 cost;
        if (ownerOf[pixelLocation] == address(0)) {
            pixelSeller = owner;
            cost = INITIAL_PIXEL_PRICE;
        } else {
            pixelSeller = ownerOf[pixelLocation];
            cost = pixels[pixelIndex].cost;
        }
        ColorChoice color = ColorChoice(colorIndex);
               
        // Calculate cut and add to owners pending withdrawls
        uint256 ownerCut = cost * OWNER_CUT_PERCENT / 100;
        pendingWithdrawals[owner] += ownerCut;
        // Add sale proceeds to seller's account for withdrawal
        pendingWithdrawals[pixelSeller] += (cost - ownerCut);
        // Create pixel with new price and new color
        Pixel memory pixel = Pixel(pixelLocation, (cost * COST_MULTIPLIER_PERCENT / 100) + cost, color);
        if (ownerOf[pixelLocation] == address(0)) {
            pixels.push(pixel);
            pixelLocationToIndex[pixelLocation] = pixels.length - 1;
        } else {
            pixels[pixelIndex] = pixel;
        }
         // Set ownership to buyer, update pixel balance of seller and buyer
        ownerOf[pixelLocation] = msg.sender;
        balanceOf[pixelSeller]--;
        balanceOf[msg.sender]++;
        
        Transfer(pixelSeller, msg.sender, pixelLocation);
        Purchase(pixelLocation, msg.value, pixelSeller, msg.sender);
        Update(pixelLocation, pixels[pixelIndex].cost, color);
    }
    /* Function for pixel seller to update price (only price reductions are allowed) */
    function updatePixel(uint pixelLocation, uint price) public postInit validLocation(pixelLocation) sellerOnly(pixelLocation) {
        uint256 pixelIndex = pixelLocationToIndex[pixelLocation];
        require(price < pixels[pixelIndex].cost);

        pixels[pixelIndex].cost = price;
        Update(pixelLocation, pixels[pixelIndex].cost, pixels[pixelIndex].color);
    }
    /* Function for pixel seller to update pixel color */
    function updatePixel(uint pixelLocation, uint8 colorIndex) public postInit validLocation(pixelLocation) validColor(colorIndex) sellerOnly(pixelLocation) {
        uint256 pixelIndex = pixelLocationToIndex[pixelLocation];
        require(colorIndex != uint8(pixels[pixelIndex].color));
        pixels[pixelIndex].color = ColorChoice(colorIndex);
        Update(pixelLocation, pixels[pixelIndex].cost, pixels[pixelIndex].color);
    }
    /* Function for pixel seller to update pixel price and color */
    function updatePixel(uint pixelLocation, uint8 colorIndex, uint price) public postInit validLocation(pixelLocation) validColor(colorIndex) sellerOnly(pixelLocation) {
        uint256 pixelIndex = pixelLocationToIndex[pixelLocation];
        require(colorIndex != uint8(pixels[pixelIndex].color));
        require(price < pixels[pixelIndex].cost);

        pixels[pixelIndex].color = ColorChoice(colorIndex);
        pixels[pixelIndex].cost = price;
        Update(pixelLocation, pixels[pixelIndex].cost, pixels[pixelIndex].color);
    }
    function withdraw() public postInit {
        uint256 amount = pendingWithdrawals[msg.sender];
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

}