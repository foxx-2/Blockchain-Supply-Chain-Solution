pragma solidity ^0.4.24;

import "../core/Ownable.sol";
import "../accessControl/ManufacturerRole.sol";
import "../accessControl/RetailerRole.sol";
import "../accessControl/CustomerRole.sol";

// Define a contract 'Supplychain'
contract SupplyChain is Ownable, ManufacturerRole, RetailerRole, CustomerRole {

    // Define 'owner'
    address contractOwner;

    // Define a variable called 'upc' for Universal Product Code (UPC)
    uint  upc;

    // Define a variable called 'sku' for Stock Keeping Unit (SKU)
    uint  sku;

    // Define a public mapping 'items' that maps the UPC to an Item.
    mapping(uint => Item) items;

    // Define a public mapping 'itemsHistory' that maps the UPC to an array of TxHash,
    // that track its journey through the supply chain -- to be sent from DApp.
    mapping(uint => string[]) itemsHistory;

    // Define enum 'State' with the following values:
    enum State
    {
        Processed, // 0
        Packed, // 1
        Added, // 2
        Received, // 3
        Shipped, // 4
        Delivered // 5
    }

    State constant defaultState = State.Processed;

    // Define a struct 'Item' with the following fields:
    struct Item {
        uint sku;  // Stock Keeping Unit (SKU)
        uint upc; // Universal Product Code (UPC), generated by the Manufacturer, goes on the package, can be verified by the Customer
        address ownerID;  // Metamask-Ethereum address of the current owner as the product moves through 6 stages
        address originManufacturerID; // Metamask-Ethereum address of the Manufacturer
        string originManufacturerName; // Manufacturer Name
        string originManufacturerInformation;  // Manufacturer Information
        string originManufacturerLatitude; // Manufacturer Latitude
        string originManufacturerLongitude;  // Manufacturer Longitude
        uint productID;  // Product ID potentially a combination of upc + sku
        string productNotes; // Product Notes
        uint productPrice; // Product Price
        State itemState;  // Product State as represented in the enum above
        address retailerID; // Metamask-Ethereum address of the Retailer
        address customerID; // Metamask-Ethereum address of the Customer
    }

    // Ownable Ownable;
    // ManufacturerRole Manufacturer;
    // RetailerRole Retailer;
    // CustomerRole Customer;

    // Define 8 events with the same 6 state values and accept 'upc' as input argument
    event Processed(uint upc);
    event Packed(uint upc);
    event Added(uint upc);
    event Received(uint upc);
    event Shipped(uint upc);
    event Delivered(uint upc);

    // Define a modifer that checks to see if msg.sender == owner() of the contract
    modifier onlyOwner() {
        require(msg.sender == owner());
        _;
    }

    // Define a modifer that verifies the Caller
    modifier verifyCaller (address _address) {
        require(owner() == _address);
        _;
    }

    // Define a modifier that checks if the paid amount is sufficient to cover the price
    modifier paidEnough(uint _price) {
        require(msg.value >= _price);
        _;
    }

    // Define a modifier that checks the price and refunds the remaining balance
    modifier checkValue(uint _upc) {
        _;
        uint _price = items[_upc].productPrice;
        uint amountToReturn = msg.value - _price;
        items[_upc].customerID.transfer(amountToReturn);
    }

    // Define a modifier that checks if an item.state of a upc is Processed
    modifier processed(uint _upc) {
        require(items[_upc].itemState == State.Processed);
        _;
    }

    // Define a modifier that checks if an item.state of a upc is Packed
    modifier packed(uint _upc) {
        require(items[_upc].itemState == State.Packed);
        _;
    }

    // Define a modifier that checks if an item.state of a upc is Added
    modifier added(uint _upc) {
        require(items[_upc].itemState == State.Added);
        _;
    }

    // Define a modifier that checks if an item.state of a upc is Received
    modifier received(uint _upc) {
        require(items[_upc].itemState == State.Received);
        _;
    }

    // Define a modifier that checks if an item.state of a upc is Shipped
    modifier shipped(uint _upc) {
        require(items[_upc].itemState == State.Shipped);
        _;
    }

    // Define a modifier that checks if an item.state of a upc is Delivered
    modifier delivered(uint _upc) {
        require(items[_upc].itemState == State.Delivered);
        _;
    }

    // In the constructor set 'sku' to 1
    // and set 'upc' to 1
    constructor() public payable {
        sku = 1;
        upc = 1;
    }

    // Define a function 'kill' if required
    function kill() public {
        if (msg.sender == contractOwner) {
            selfdestruct(contractOwner);
        }
    }

    // Define a function 'processItem' that allows a farmer to mark an item 'Processed'
    function processItem(uint _upc, address _originManufacturerID, string _originManufacturerName, string _originManufacturerInformation, string _originManufacturerLatitude, string _originManufacturerLongitude) public
    onlyOwner()
    {
        addManufacturer(_originManufacturerID);
        transferOwnership(_originManufacturerID);

        // Add the new item as part of Processed
        Item memory newItem;
        newItem.upc = _upc;
        newItem.sku = sku;
        newItem.productID = sku + _upc;
        newItem.ownerID = _originManufacturerID;
        newItem.originManufacturerID = _originManufacturerID;
        newItem.originManufacturerName = _originManufacturerName;
        newItem.originManufacturerInformation = _originManufacturerInformation;
        newItem.originManufacturerLatitude = _originManufacturerLatitude;
        newItem.originManufacturerLongitude = _originManufacturerLongitude;
        newItem.itemState = defaultState;

        items[_upc] = newItem;

        // Increment sku
        sku = sku + 1;
        // Emit the appropriate event
        emit Processed(_upc);
    }

    // Define a function 'packItem' that allows a farmer to mark an item 'Packed'
    function packItem(uint _upc) public
    onlyOwner()
    onlyManufacturer()
        // Call modifier to check if upc has passed previous supply chain stage
    processed(_upc)

        // Call modifier to verify caller of this function
    verifyCaller(items[_upc].ownerID)
    {
        // Update the appropriate fields
        items[_upc].itemState = State.Packed;

        // Emit the appropriate event
        emit Packed(_upc);
    }

    // Define a function 'addItem' that allows a Manufacturer to sell the item
    function addItem(uint _upc, uint _price, address retailerID) public
    onlyOwner()
    onlyManufacturer()
        // Call modifier to check if upc has passed previous supply chain stage
    packed(_upc)

        // Call modifier to verify caller of this function
    verifyCaller(items[_upc].ownerID)
    {
        addRetailer(retailerID);
        transferOwnership(retailerID);

        // Update the appropriate fields
        items[_upc].ownerID = retailerID;
        items[_upc].retailerID = retailerID;
        items[_upc].itemState = State.Added;
        items[_upc].productPrice = _price;

        // Emit the appropriate event
        emit Added(_upc);
    }

    // Define a function 'receiveItem' that allows the retailer to mark an item 'Received'
    // Use the above modifiers to check if the item is added
    function receiveItem(uint _upc, string productNotes) public
    onlyOwner()
    onlyRetailer()
        // Call modifier to check if upc has passed previous supply chain stage
    added(_upc)

        // Access Control List enforced by calling Smart Contract / DApp
    verifyCaller(items[_upc].ownerID)
    {

        // Update the appropriate fields
        items[_upc].productNotes = productNotes;
        items[_upc].itemState = State.Received;

        // Emit the appropriate event
        emit Received(_upc);
    }

    // Define a function 'shipItem' that allows the retailer to mark an item 'Shipped'
    // Use the above modifers to check if the item is sold
    function shipItem(uint _upc, address customerID) public
    onlyOwner()
    onlyRetailer()
        // Call modifier to check if upc has passed previous supply chain stage
    received(_upc)
        // Call modifier to verify caller of this function
    verifyCaller(items[_upc].ownerID)
    {
        addCustomer(customerID);
        transferOwnership(customerID);
        // Update the appropriate fields
        items[_upc].customerID = customerID;
        items[_upc].itemState = State.Shipped;

        // Emit the appropriate event
        emit Shipped(_upc);
    }

    // Define a function 'buyItem' that allows the customer to mark an item 'Delivered'
    // Use the above defined modifiers to check if the item is available for sale, if the buyer has paid enough,
    // and any excess ether sent is refunded back to the buyer
    function buyItem(uint _upc) public payable
    onlyOwner()
    onlyCustomer()
        // Call modifier to check if upc has passed previous supply chain stage
    shipped(_upc)
        // Call modifer to check if buyer has paid enough
    paidEnough(items[_upc].productPrice)
        // Call modifer to send any excess ether back to buyer
    checkValue(_upc)
    {
        // Update the appropriate fields - ownerID, customerID, itemState
        items[_upc].ownerID = msg.sender;
        items[_upc].customerID = msg.sender;
        items[_upc].itemState = State.Delivered;

        // Transfer money to Manufacturer and Retailer
        items[_upc].originManufacturerID.transfer((items[_upc].productPrice * 7) / 10);
        items[_upc].retailerID.transfer((items[_upc].productPrice * 3) / 10);

        // emit the appropriate event
        emit Delivered(_upc);
    }

    // Define a function 'fetchItem' that fetches the data
    function fetchItem(uint _upc) public view returns
    (
        uint itemSKU,
        uint itemUPC,
        address ownerID,
        address originManufacturerID,
        string originManufacturerName,
        State itemState,
        uint productPrice,
        address retailerID,
        address customerID
    )
    {
        // Assign values to the parameters

        itemSKU = items[_upc].sku;
        itemUPC = items[_upc].upc;
        ownerID = items[_upc].ownerID;
        originManufacturerID = items[_upc].originManufacturerID;
        originManufacturerName = items[_upc].originManufacturerName;
        itemState = items[_upc].itemState;
        productPrice = items[_upc].productPrice;
        retailerID = items[_upc].retailerID;
        customerID = items[_upc].customerID;

        return
        (
        itemSKU,
        itemUPC,
        ownerID,
        originManufacturerID,
        originManufacturerName,
        itemState,
        productPrice,
        retailerID,
        customerID
        );
    }

    // Define a function 'fetchItemDetails' that fetches the item details
    function fetchItemDetails(uint _upc) public view returns
    (
        uint productID,
        uint itemUPC,
        uint productPrice,
        string productNotes,
        string originManufacturerName,
        string originManufacturerInformation,
        string originManufacturerLatitude,
        string originManufacturerLongitude
    )
    {
        // Assign values to the parameters

        productID = items[_upc].productID;
        itemUPC = items[_upc].upc;
        productPrice = items[_upc].productPrice;
        productNotes = items[_upc].productNotes;
        originManufacturerName = items[_upc].originManufacturerName;
        originManufacturerInformation = items[_upc].originManufacturerInformation;
        originManufacturerLatitude = items[_upc].originManufacturerLatitude;
        originManufacturerLongitude = items[_upc].originManufacturerLongitude;

        return
        (
        productID,
        itemUPC,
        productPrice,
        productNotes,
        originManufacturerName,
        originManufacturerInformation,
        originManufacturerLatitude,
        originManufacturerLongitude
        );
    }

//    function addItemHistory(uint _upc, string txHash) {
//        itemsHistory[_upc].push(txHash);
//    }
//
//    function getItemHistory(uint _upc) public view returns (string[]) {
//        return itemsHistory[_upc];
//    }
}
