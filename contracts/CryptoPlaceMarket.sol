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
    uint public nextPixelIndexToAssign = 0;

    bool public allPixelsAssigned = false;
    uint public pixelsRemainingToAssign = 0;

    struct Pixel {
        uint pixelIndex;
        address seller;
        uint cost;
        string color;
    }

    //mapping (address => uint) public addressToPixelIndex;
    mapping (uint => address) public pixelIndexToAddress;
    /* This creates an array with all balances */
    mapping (address => uint256) public balanceOf;
    // A record of pixels that are offered for sale at a specific minimum value, and perhaps to a specific person
    mapping (uint => Pixel) public pixelInfo;
    // A record of the highest pixel bid
    //mapping (uint => Bid) public pixelBids;
    mapping (address => uint) public pendingWithdrawals;

    event Assign(address indexed to, uint256 pixelIndex);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event PixelTransfer(address indexed from, address indexed to, uint256 pixelIndex);
    //event PixelOffered(uint indexed pixelIndex, uint minValue, address indexed toAddress);
    //event PixelBidEntered(uint indexed pixelIndex, uint value, address indexed fromAddress);
    //event PixelBidWithdrawn(uint indexed pixelIndex, uint value, address indexed fromAddress);
    event PixelBought(uint indexed pixelIndex, uint value, address indexed fromAddress, address indexed toAddress, uint newCost, string newColor);
    //event PixelNoLongerForSale(uint indexed pixelIndex);

    /* Initializes contract with initial supply tokens to the creator of the contract */
    function CryptoPlaceMarket() public payable {
        balanceOf[msg.sender] = TOTAL_PIXELS;
        owner = msg.sender;
        totalSupply = TOTAL_PIXELS;                        // Update total supply
        pixelsRemainingToAssign = TOTAL_PIXELS;
        name = "CRYPTOPLACE";                                   // Set the name for display purposes
        symbol = "₽";                               // Set the symbol for display purposes
        decimals = 0;                                       // Amount of decimals for display purposes
    }

    function setInitialOwner(address to, uint pixelIndex) public {
        require(msg.sender == owner);
        require(allPixelsAssigned != true);
        require(pixelIndex < TOTAL_PIXELS);
        if (pixelIndexToAddress[pixelIndex] != to) {
            if (pixelIndexToAddress[pixelIndex] != 0x0) {
                balanceOf[pixelIndexToAddress[pixelIndex]]--;
            } else {
                pixelsRemainingToAssign--;
            }
            pixelIndexToAddress[pixelIndex] = to;
            balanceOf[to]++;
            Assign(to, pixelIndex);
        }
    }

    function setInitialOwners(address[] addresses, uint[] indices) public {
        require(msg.sender == owner);
        uint n = addresses.length;
        for (uint i = 0; i < n; i++) {
            setInitialOwner(addresses[i], indices[i]);
        }
    }

    function allInitialOwnersAssigned() public {
        require(msg.sender == owner);
        allPixelsAssigned = true;
    }

    // Transfer ownership of a pixel to another user without requiring payment
    function transferPixel(address to, uint pixelIndex) public {
        require(allPixelsAssigned == true);
        require(pixelIndex < TOTAL_PIXELS);
        require(pixelIndexToAddress[pixelIndex] == msg.sender);
        

        pixelIndexToAddress[pixelIndex] = to;
        balanceOf[msg.sender]--;
        balanceOf[to]++;
        Transfer(msg.sender, to, 1);
        PixelTransfer(msg.sender, to, pixelIndex);
    }
    //TODO: Add fee structure? Reduce what seller gets by 1%?
    function buyPixel(uint pixelIndex, string color) public payable {
        require(allPixelsAssigned == true);
        require(pixelIndex < TOTAL_PIXELS);
        Pixel memory pixel = pixelInfo[pixelIndex];
        address pixelSeller;
        uint pixelCost;
        if (pixel.seller == 0x0) {
            pixelSeller = owner;
            pixelCost = INITIAL_PIXEL_PRICE;
        } else {
            pixelSeller = pixel.seller;
            pixelCost = pixel.cost;
        }
        //TODO:: Restrict payment to equal cost? Put extra in withdrawal balance maybe?    
        require(msg.value >= pixelCost);

        pixelIndexToAddress[pixelIndex] = msg.sender;
        balanceOf[pixelSeller]--;
        balanceOf[msg.sender]++;
        Transfer(pixelSeller, msg.sender, 1);

        pendingWithdrawals[pixelSeller] += msg.value;
        pixelInfo[pixelIndex] = Pixel(pixelIndex, msg.sender, (pixelCost * (COST_MULTIPLIER / 10)) + pixelCost, color);
        PixelBought(pixelIndex, msg.value, pixelSeller, msg.sender, pixelInfo[pixelIndex].cost, color);
    }

    function withdraw() public {
        require(allPixelsAssigned == true);
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
        msg.sender.transfer(amount);
    }

}