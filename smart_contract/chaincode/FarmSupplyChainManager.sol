// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../ownership/OwnershipTransferContract.sol";
import "../access/FarmerAccessRole.sol";
import "../access/DistributorAccessRole.sol";
import "../access/RetailerAccessRole.sol";
import "../access/ConsumerAccessRole.sol";


/**
*   Smart Contract : Farm Supply Chain Management
*
*   Problem Statement:
*   Many people across the globe are getting sick due to food hygiene. 
*   A better tracking technique is required to trace back the origin of the food item so that 
*   the end-user can authenticate that food item and consume that without any worry.
*/

contract FarmSupplyChainManager is Ownable, FarmerRole, DistributorRole, RetailerRole, ConsumerRole {
    
    // Define contract variables
    uint256 public productCode;
    uint256 public stockUnitCount;

    // Mappings to track products and transaction history
    mapping(uint256 => Item) public items;
    mapping(uint256 => Txblocks) public itemsHistory;

    enum State {
        ItemProducedByFarmer, 
        SoldByFarmer, 
        BoughtByDistributor, 
        ShippedByFarmerToDistributor, 
        ReceivedByDistributor, 
        ProcessedByDistributor, 
        PackagedByDistributor, 
        SoldByDistributor, 
        BoughtByRetailer, 
        ShippedByDistributorToRetailer, 
        ReceivedByRetailer, 
        SoldByRetailer, 
        BoughtByConsumer
    }

    State constant defaultState = State.ItemProducedByFarmer;

    struct Item {
        uint256 stockUnitCount;
        uint256 productCode;
        address ownerAddressID;
        address farmerAddressID;
        string farmName;
        string farmInformation;
        string farmLatitude;
        string farmLongitude;
        uint256 productID;
        string productDescription;
        uint256 productHarvestDate;
        uint256 productPrice;
        uint256 productSliced;
        State itemState;
        address distributorAddressID;
        address retailerAddressID;
        address consumerAddressID;
        string producerName;  
        string distributorName;
        string retailerName;   
        uint256 prodToDistDate;
        uint256 distToRetaDate;
    }

    struct Txblocks {
        uint256 FTD; //Farmer to Distributor
        uint256 DTR; //Distributor to Retailer  
        uint256 RTC; //Retailer to Consumer  
        uint256 prodToDistTimestamp; // Timestamp for product from farmer to distributor
        uint256 distToRetaTimestamp; // Timestamp for product from distributor to retailer
    }

    event ItemProducedByFarmer(uint256 productCode);
    event SoldByFarmer(uint256 productCode);
    event BoughtByDistributor(uint256 productCode);
    event ShippedByFarmerToDistributor(uint256 productCode);
    event ReceivedByDistributor(uint256 productCode);
    event ProcessedByDistributor(uint256 productCode);
    event PackagedByDistributor(uint256 productCode);
    event SoldByDistributor(uint256 productCode);
    event BoughtByRetailer(uint256 productCode);
    event ShippedByDistributorToRetailer(uint256 productCode);
    event ReceivedByRetailer(uint256 productCode);
    event SoldByRetailer(uint256 productCode);
    event BoughtByConsumer(uint256 productCode);

    // Define a modifer that checks to see if _msgSender() == owner of the contract
    modifier only_Owner() {
        require(_msgSender() == owner);
        _;
    }

    // Define a modifer that verifies the Caller
    modifier verifyCaller(address _address) {
        require(_msgSender() == _address);
        _;
    }

    // Define a modifier that checks if the paid amount is sufficient to cover the price
    modifier paidEnough(uint256 _price) {
        require(msg.value >= _price);
        _;
    }

    // Define a modifier that checks the price and refunds the remaining balance
    modifier checkValue(uint256 _productCode) {
        uint256 price = items[_productCode].productPrice;
        uint256 refund = msg.value - price;
        require(refund >= 0, "Refund cannot be negative");
        if (refund > 0) {
            payable(_msgSender()).transfer(refund);
        }
        _;
    }


    modifier onlyState(uint256 _productCode, State state) {
        require(items[_productCode].itemState == state, "State mismatch");
        _;
    }

    constructor() payable {
        owner = _msgSender();
        stockUnitCount = 1;
        productCode = 1;
    }

    /*
        1st step in supplychain
        Allows farmer to create product item.
    */
    function produceItemByFarmer(
        uint256 _productCode,
        string memory _farmName,
        string memory _farmInformation,
        string memory _farmLatitude,
        string memory _farmLongitude,
        string memory _productDescription,
        uint256 _price,
        string memory _producerName
    ) public onlyFarmer {
        // Check if the product with the same product code already exists
        require(items[_productCode].productCode == 0, "Product already exists.");

        Item memory newItem;
        newItem.stockUnitCount = stockUnitCount;
        newItem.productCode = _productCode;
        newItem.ownerAddressID = _msgSender();
        newItem.farmerAddressID = _msgSender();
        newItem.farmName = _farmName;
        newItem.farmInformation = _farmInformation;
        newItem.farmLatitude = _farmLatitude;
        newItem.farmLongitude = _farmLongitude;
        newItem.productID = _productCode + stockUnitCount;
        newItem.productDescription = _productDescription;
        newItem.productPrice = _price;
        newItem.productHarvestDate = block.timestamp;
        newItem.productSliced = 0;
        newItem.itemState = defaultState;
        newItem.distributorAddressID = address(0); 
        newItem.retailerAddressID = address(0); 
        newItem.consumerAddressID = address(0); 
        newItem.producerName = _producerName; 
        newItem.distributorName = ""; 
        newItem.retailerName = ""; 
        
        items[_productCode] = newItem;
        
        Txblocks memory txblock;
        itemsHistory[_productCode] = txblock;

        stockUnitCount++;

        emit ItemProducedByFarmer(_productCode);
    }


    /*
        2nd step in supplychain
        Allows farmer to sell product item.
    */
    function sellItemByFarmer(uint256 _productCode, uint256 _price) public onlyFarmer onlyState(_productCode, State.ItemProducedByFarmer) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.SoldByFarmer;
        items[_productCode].productPrice = _price;
        emit SoldByFarmer(_productCode);
    }

    /*
        3rd step in supplychain
        Allows distributor to purchase product item.
    */
    function purchaseItemByDistributor(uint256 _productCode, string memory _distributorName) public payable onlyDistributor onlyState(_productCode, State.SoldByFarmer) paidEnough(items[_productCode].productPrice) checkValue(_productCode) {
        
        // Ensure the product exists in the ledger
        require(items[_productCode].productCode != 0, "Asset not found in the ledger");

        address payable farmerAddress = payable(items[_productCode].farmerAddressID);
        (bool sent, ) = farmerAddress.call{value: items[_productCode].productPrice}("");
        require(sent, "Error! Payment to farmer failed. Could not send Ether to the specified address.");

        // Transfer ownership to the distributor
        transferOwnership(_productCode, _msgSender());

        items[_productCode].distributorName = _distributorName; // Set the distributor name
        
        items[_productCode].itemState = State.BoughtByDistributor;  // Update the state of the product to "BoughtByDistributor"
        
        items[_productCode].prodToDistDate = block.timestamp;   // Set the prodToDistDate to the current block timestamp (the date the product is transferred to the distributor)
    
        itemsHistory[_productCode].FTD = block.number;      // Record the transaction block number
        itemsHistory[_productCode].prodToDistTimestamp = block.timestamp;

        emit BoughtByDistributor(_productCode); // Emit an event for the purchase
    }

    /*
        4th step in supplychain
        Allows farmer to ship product item purchased by the distributor.
    */
    function shipItemToDistributorByFarmer(uint256 _productCode) public onlyFarmer onlyState(_productCode, State.BoughtByDistributor) verifyCaller(items[_productCode].farmerAddressID) {
        items[_productCode].itemState = State.ShippedByFarmerToDistributor;
        emit ShippedByFarmerToDistributor(_productCode);
    }

    /*
        5th step in supplychain
        Allows distributor to receive product item.
    */
    function receivedItemByDistributor(uint256 _productCode) public onlyDistributor onlyState(_productCode, State.ShippedByFarmerToDistributor) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.ReceivedByDistributor;
        emit ReceivedByDistributor(_productCode);
    }

     /*
        6th step in supplychain
        Allows distributor to process product item.
    */
    function processedItemByDistributor(uint256 _productCode, uint256 slices) public onlyDistributor onlyState(_productCode, State.ReceivedByDistributor) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.ProcessedByDistributor;
        items[_productCode].productSliced = slices;
        emit ProcessedByDistributor(_productCode);
    }

    /*
        7th step in supplychain
        Allows distributor to package product item.
    */
    function packageItemByDistributor(uint256 _productCode) public onlyDistributor onlyState(_productCode, State.ProcessedByDistributor) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.PackageByDistributor;
        emit PackagedByDistributor(_productCode);
    }


    /*
        8th step in supplychain
        Allows distributor to sell product item.
    */
    function sellItemByDistributor(uint256 _productCode, uint256 _price) public onlyDistributor onlyState(_productCode, State.PackageByDistributor) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.SoldByDistributor;
        items[_productCode].productPrice = _price;
        emit SoldByDistributor(_productCode);
    }

    /*
        9th step in supplychain
        Allows retailer to purchase product item.
    */
    function purchaseItemByRetailer(uint256 _productCode, string memory _retailerName) public payable onlyRetailer onlyState(_productCode, State.SoldByDistributor) paidEnough(items[_productCode].productPrice) checkValue(_productCode) {

        // Ensure the product exists in the ledger
        require(items[_productCode].productCode != 0, "Asset not found in the ledger");

        address payable distributorAddress = payable(items[_productCode].distributorAddressID);
        (bool sent, ) = distributorAddress.call{value: items[_productCode].productPrice}("");
        require(sent, "Error! Payment to distributor failed. Could not send Ether to the specified address.");

        // Transfer ownership to the retailer
        transferOwnership(_productCode, _msgSender());
        items[_productCode].retailerName = _retailerName;           // Set the retailer name

        items[_productCode].itemState = State.BoughtByRetailer;     // Update the state of the product to "BoughtByRetailer"

        items[_productCode].distToRetaDate = block.timestamp;   // Set the distToRetaDate to the current block timestamp (the date the product is transferred to the retailer)

        itemsHistory[_productCode].DTR = block.number;      // Record the transaction block number
        itemsHistory[_productCode].distToRetaTimestamp = block.timestamp;

        emit BoughtByRetailer(_productCode);            // Emit an event for the purchase
    }

    /*
        10th step in supplychain
        Allows distributor to ship the product item to the retailer.
    */
    function shippedItemByDistributor(uint256 _productCode) public onlyDistributor onlyState(_productCode, State.BoughtByRetailer) verifyCaller(items[_productCode].distributorAddressID) {
        items[_productCode].itemState = State.ShippedByDistributorToRetailer;
        emit ShippedByDistributorToRetailer(_productCode);
    }

    /*
        11th step in supplychain
        Allows retailer to receive product item.
    */
    function receivedItemByRetailer(uint256 _productCode) public onlyRetailer onlyState(_productCode, State.ShippedByDistributorToRetailer) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.ReceivedByRetailer;
        emit ReceivedByRetailer(_productCode);
    }

    /*
        12th step in supplychain
        Allows retailer to sell the product item.
    */
    function sellItemByRetailer(uint256 _productCode, uint256 _price) public onlyRetailer onlyState(_productCode, State.ReceivedByRetailer) verifyCaller(items[_productCode].ownerAddressID) {
        items[_productCode].itemState = State.SoldByRetailer;
        items[_productCode].productPrice = _price;
        emit SoldByRetailer(_productCode);
    }

    /*
        13th step in supplychain
        Allows consumer to purchase the product item from the retailer.
    */
    function purchaseItemByConsumer(uint256 _productCode) public payable onlyConsumer onlyState(_productCode, State.SoldByRetailer) paidEnough(items[_productCode].productPrice) checkValue(_productCode) {
        address payable retailerAddress = payable(items[_productCode].retailerAddressID);
        (bool sent, ) = retailerAddress.call{value: items[_productCode].productPrice}("");
        require(sent, "Error! Payment to retailer failed. Could not send Ether to the specified address.");

        // Transfer ownership to the consumer
        transferOwnership(_productCode, _msgSender());

        items[_productCode].itemState = State.BoughtByConsumer;     // Update the state of the product to "BoughtByConsumer"

        itemsHistory[_productCode].RTC = block.number;      // Record the transaction block number
        emit BoughtByConsumer(_productCode);    // Emit an event for the purchase
    }

    // Function to transfer ownership
    function transferOwnership(uint256 _productCode, address _newOwner) internal {
        address oldOwner = items[_productCode].ownerAddressID;
        items[_productCode].ownerAddressID = _newOwner;
        
        // Update the roles of the new owner
        if (_newOwner != address(0)) {
            if (items[_productCode].farmerAddressID == oldOwner) {
                items[_productCode].farmerAddressID = address(0); // Clear the old farmer address
            } else if (items[_productCode].distributorAddressID == oldOwner) {
                items[_productCode].distributorAddressID = address(0); // Clear the old distributor address
            } else if (items[_productCode].retailerAddressID == oldOwner) {
                items[_productCode].retailerAddressID = address(0); // Clear the old retailer address
            } else if (items[_productCode].consumerAddressID == oldOwner) {
                items[_productCode].consumerAddressID = address(0); // Clear the old consumer address
            }
        }
    }


    
    /**
    *   @dev View asset details from the ledger.
    *   This function helps to retrieve asset product details from the ledger.
    *   @param _productCode the product ID of the farm product
    *   @return Farm Product supply chain details
    */
    function fetchAssetDetails(uint256 _productCode) public view returns (
        uint256 stockUnitCount,
        uint256 productCode,
        address ownerAddressID,
        address farmerAddressID,
        string memory farmName,
        string memory farmInformation,
        string memory farmLatitude,
        string memory farmLongitude,
        uint256 productID,
        string memory productDescription,
        uint256 productHarvestDate,
        uint256 productPrice,
        uint256 productSliced,
        State itemState,
        address distributorAddressID,
        address retailerAddressID,
        address consumerAddressID,
        uint256 blockFarmerToDistributor,
        uint256 blockDistributorToRetailer,
        uint256 blockRetailerToConsumer,
        string producerName,
        string distributorName,
        string retailerName,
        uint256 prodToDistDate,
        uint256 distToRetaDate
    ) {
        // Fetch the item details from the ledger (items mapping)
        Item memory item = items[_productCode];
        Txblocks memory txblock = itemsHistory[_productCode];

        // Return the combined asset details
        return (
            item.stockUnitCount,
            item.productCode,
            item.ownerAddressID,
            item.farmerAddressID,
            item.farmName,
            item.farmInformation,
            item.farmLatitude,
            item.farmLongitude,
            item.productID,
            item.productDescription,
            item.productHarvestDate,
            item.productPrice,
            item.productSliced,
            item.itemState,
            item.distributorAddressID,
            item.retailerAddressID,
            item.consumerAddressID,
            item.producerName,
            item.distributorName,
            item.retailerName,
            item.prodToDistDate,
            item.distToRetaDate,
            txblock.FTD,
            txblock.DTR,
            txblock.RTC
        );
    }
}