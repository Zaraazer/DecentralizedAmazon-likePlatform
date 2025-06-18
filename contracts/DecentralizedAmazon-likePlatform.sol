\
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract DecentralizedAmazonPlatform {
    address public owner;
    uint256 public productCounter;
    uint256 public orderCount
    
    struct
        uint256 id;
        string name;
        string description;
        uint256 price;
        address seller;
        bool isAct
        string imageHash; // IPFS hash for product image
        uint256 timestamp;
    }

struct Product {
        uint256 id;
        string name;
        string description;
        uint256 price;
        uint256 quantity;
        address seller;
        bool isAct
        string imageHash; // IPFS hash for product image
        uint256 timestamp;
    }
    
    struct Order {
        uint256 id;
        uint256 productId;
        uint256 quantity;
        uint256 totalPrice;
        address buyer;
        address seller;
        OrderStatus status;
        uint256 timestamp;
    }
    
    enum OrderStatus { Pending, Shipped, Delivered, Cancelled }
    
    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public sellerProducts;
    mapping(address => uint256[]) public buyerOrders;
    mapping(address => uint256) public sellerBalances;
    
    event ProductListed(uint256 indexed productId, string name, uint256 price, address indexed seller);
    event ProductPurchased(uint256 indexed orderId, uint256 indexed productId, address indexed buyer, uint256 quantity);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus status);
    event FundsWithdrawn(address indexed seller, uint256 amount);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    modifier onlyProductSeller(uint256 _productId) {
        require(products[_productId].seller == msg.sender, "Only product seller can call this function");
        _;
    }
    
    modifier onlyOrderParticipant(uint256 _orderId) {
        require(orders[_orderId].buyer == msg.sender || orders[_orderId].seller == msg.sender, 
                "Only buyer or seller can call this function");
        _;
    }
    
    constructor() {
        owner = msg.sender;
        productCounter = 0;
        orderCounter = 0;
    }
    
    /**
     * @dev Core Function 1: List a new product on the marketplace
     * @param _name Product name
     * @param _description Product description
     * @param _price Product price in wei
     * @param _quantity Available quantity
     * @param _imageHash IPFS hash for product image
     */
    function listProduct(
        string memory _name,
        string memory _description,
        uint256 _price,
        uint256 _quantity,
        string memory _imageHash
    ) external {
        require(bytes(_name).length > 0, "Product namcannot be empty");
        require(_price > 0, "Price must be greater than 0");
        require(_quantity > 0, "Quantity must be greater than 0");
        
        productCounter++;
        
        products[productCounter] = Product({
            id: productCounter,
            name: _name,
            description: _description,
            price: _price,
            quantity: _quantity,
            seller: msg.sender,
            isActive: true,
            imageHash: _imageHash,
            timestamp: block.timestamp
        });
        
        sellerProducts[msg.sender].push(productCounter);
        
        emit ProductListed(productCounter, _name, _price, msg.sender);
    }
    
    /**
     * @dev Core Function 2: Purchase a product and create an order
     * @param _productId ID of the product to purchase
     * @param _quantity Quantity to purchase
     */
    function purchaseProduct(uint256 _productId, uint256 _quantity) external payable {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        require(products[_productId].isActive, "Product is not active");
        require(products[_productId].quantity >= _quantity, "Insufficient product quantity");
        require(_quantity > 0, "Quantity must be greater than 0");
        
        uint256 totalPrice = products[_productId].price * _quantity;
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Update product quantity
        products[_productId].quantity -= _quantity;
        if (products[_productId].quantity == 0) {
            products[_productId].isActive = false;
        }
        
        // Create order
        orderCounter++;
        orders[orderCounter] = Order({
            id: orderCounter,
            productId: _productId,
            quantity: _quantity,
            totalPrice: totalPrice,
            buyer: msg.sender,
            seller: products[_productId].seller,
            status: OrderStatus.Pending,
            timestamp: block.timestamp
        });
        
        buyerOrders[msg.sender].push(orderCounter);
        
        // Add funds to seller's balance (minus platform fee)
        uint256 platformFee = totalPrice * 2 / 100; // 2% platform fee
        uint256 sellerAmount = totalPrice - platformFee;
        sellerBalances[products[_productId].seller] += sellerAmount;
        sellerBalances[owner] += platformFee;
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        
        emit ProductPurchased(orderCounter, _productId, msg.sender, _quantity);
    }
    
    /**
     * @dev Core Function 3: Update order status and manage order lifecycle
     * @param _orderId ID of the order to update
     * @param _status New status for the order
     */
    function updateOrderStatus(uint256 _orderId, OrderStatus _status) external onlyOrderParticipant(_orderId) {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        require(orders[_orderId].status != OrderStatus.Delivered, "Order already delivered");
        require(orders[_orderId].status != OrderStatus.Cancelled, "Order already cancelled");
        
        // Only seller can mark as shipped, only buyer can mark as delivered
        if (_status == OrderStatus.Shipped) {
            require(msg.sender == orders[_orderId].seller, "Only seller can mark as shipped");
            require(orders[_orderId].status == OrderStatus.Pending, "Order must be pending");
        } else if (_status == OrderStatus.Delivered) {
            require(msg.sender == orders[_orderId].buyer, "Only buyer can mark as delivered");
            require(orders[_orderId].status == OrderStatus.Shipped, "Order must be shipped first");
        } else if (_status == OrderStatus.Cancelled) {
            require(orders[_orderId].status == OrderStatus.Pending, "Can only cancel pending orders");
            
            // Refund buyer and restore product quantity
            payable(orders[_orderId].buyer).transfer(orders[_orderId].totalPrice);
            products[orders[_orderId].productId].quantity += orders[_orderId].quantity;
            products[orders[_orderId].productId].isActive = true;
            
            // Remove funds from seller balance
            uint256 platformFee = orders[_orderId].totalPrice * 2 / 100;
            uint256 sellerAmount = orders[_orderId].totalPrice - platformFee;
            sellerBalances[orders[_orderId].seller] -= sellerAmount;
            sellerBalances[owner] -= platformFee;
        }
        
        orders[_orderId].status = _status;
        emit OrderStatusUpdated(_orderId, _status);
    }
    
    // Additional utility functions
    function withdrawFunds() external {
        uint256 balance = sellerBalances[msg.sender];
        require(balance > 0, "No funds to withdraw");
        
        sellerBalances[msg.sender] = 0;
        payable(msg.sender).transfer(balance);
        
        emit FundsWithdrawn(msg.sender, balance);
    }
    
    function getActiveProducts() external view returns (Product[] memory) {
        uint256 activeCount = 0;
        
        // Count active products
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].isActive) {
                activeCount++;
            }
        }
        
        // Create array of active products
        Product[] memory activeProducts = new Product[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].isActive) {
                activeProducts[index] = products[i];
                index++;
            }
        }
        
        return activeProducts;
    }
    
    function getSellerProducts(address _seller) external view returns (uint256[] memory) {
        return sellerProducts[_seller];
    }
    
    function getBuyerOrders(address _buyer) external view returns (uint256[] memory) {
        return buyerOrders[_buyer];
    }
    
    function getSellerBalance(address _seller) external view returns (uint256) {
        return sellerBalances[_seller];
    }
    
    function getProductDetails(uint256 _productId) external view returns (Product memory) {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        return products[_productId];
    }
    
    function getOrderDetails(uint256 _orderId) external view returns (Order memory) {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");
        return orders[_orderId];
    }
}
