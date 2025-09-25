// SPDX-License-Identifier:
pragma solidity ^0.8.19;

contract DecentralizedAmazonPlatform {
    address public owner;
    uint256 public productCounter;
    uint256 public orderCounter;

    constructor() {
        owner = msg.sender;
        productCounter = 0;
        orderCounter = 0;
    }

    enum OrderStatus { Pending, Shipped, Delivered, Cancelled }

    struct Product {
        uint256 id;
        string name;
        string description;
        uint256 price;
        uint256 quantity;
        address seller;
        bool isActive;
        string imageHash;
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

    mapping(uint256 => Product) public products;
    mapping(uint256 => Order) public orders;
    mapping(address => uint256[]) public sellerProducts;
    mapping(address => uint256[]) public buyerOrders;
    mapping(address => uint256) public sellerBalances;
    mapping(uint256 => uint256[]) public productOrders;

    event ProductListed(uint256 indexed productId, string name, uint256 price, address indexed seller);
    event ProductPurchased(uint256 indexed orderId, uint256 indexed productId, address indexed buyer, uint256 quantity);
    event OrderStatusUpdated(uint256 indexed orderId, OrderStatus status);
    event FundsWithdrawn(address indexed seller, uint256 amount);
    event ProductUpdated(uint256 indexed productId);
    event ProductDeactivated(uint256 indexed productId);
    event ProductReactivated(uint256 indexed productId);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    modifier onlyProductSeller(uint256 _productId) {
        require(products[_productId].seller == msg.sender, "Only product seller can call this function");
        _;
    }

    modifier onlyOrderParticipant(uint256 _orderId) {
        require(
            orders[_orderId].buyer == msg.sender || orders[_orderId].seller == msg.sender,
            "Only buyer or seller can call this function"
        );
        _;
    }

    function listProduct(
        string memory _name,
        string memory _description,
        uint256 _price,
        uint256 _quantity,
        string memory _imageHash
    ) external {
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

    function purchaseProduct(uint256 _productId, uint256 _quantity) external payable {
        require(_productId > 0 && _productId <= productCounter, "Invalid product ID");
        Product storage product = products[_productId];
        require(product.isActive, "Product is not active");
        require(product.quantity >= _quantity, "Insufficient quantity");
        require(_quantity > 0, "Quantity must be greater than 0");

        uint256 totalPrice = product.price * _quantity;
        require(msg.value >= totalPrice, "Insufficient payment");

        product.quantity -= _quantity;
        if (product.quantity == 0) {
            product.isActive = false;
        }

        orderCounter++;
        orders[orderCounter] = Order({
            id: orderCounter,
            productId: _productId,
            quantity: _quantity,
            totalPrice: totalPrice,
            buyer: msg.sender,
            seller: product.seller,
            status: OrderStatus.Pending,
            timestamp: block.timestamp
        });

        buyerOrders[msg.sender].push(orderCounter);
        productOrders[_productId].push(orderCounter);

        uint256 platformFee = (totalPrice * 2) / 100;
        uint256 sellerAmount = totalPrice - platformFee;
        sellerBalances[product.seller] += sellerAmount;
        sellerBalances[owner] += platformFee;

        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }

        emit ProductPurchased(orderCounter, _productId, msg.sender, _quantity);
    }

    function updateOrderStatus(uint256 _orderId, OrderStatus _status) external onlyOrderParticipant(_orderId) {
        require(_orderId > 0 && _orderId <= orderCounter, "Invalid order ID");

        Order storage order = orders[_orderId];
        require(order.status != OrderStatus.Delivered && order.status != OrderStatus.Cancelled, "Final state reached");

        if (_status == OrderStatus.Shipped) {
            require(msg.sender == order.seller, "Only seller can mark as shipped");
            require(order.status == OrderStatus.Pending, "Must be pending");
        } else if (_status == OrderStatus.Delivered) {
            require(msg.sender == order.buyer, "Only buyer can mark as delivered");
            require(order.status == OrderStatus.Shipped, "Must be shipped first");
        } else if (_status == OrderStatus.Cancelled) {
            require(order.status == OrderStatus.Pending, "Only pending orders can be cancelled");

            payable(order.buyer).transfer(order.totalPrice);
            Product storage product = products[order.productId];
            product.quantity += order.quantity;
            product.isActive = true;

            uint256 platformFee = (order.totalPrice * 2) / 100;
            uint256 sellerAmount = order.totalPrice - platformFee;
            sellerBalances[order.seller] -= sellerAmount;
            sellerBalances[owner] -= platformFee;
        }

        order.status = _status;
        emit OrderStatusUpdated(_orderId, _status);
    }

    function withdrawFunds() external {
        uint256 amount = sellerBalances[msg.sender];
        require(amount > 0, "No funds available");
        sellerBalances[msg.sender] = 0;
        payable(msg.sender).transfer(amount);
        emit FundsWithdrawn(msg.sender, amount);
    }

    // ✅ New Admin/Product Functions

    function deactivateProduct(uint256 _productId) external onlyProductSeller(_productId) {
        Product storage product = products[_productId];
        require(product.isActive, "Already inactive");
        product.isActive = false;
        emit ProductDeactivated(_productId);
    }

    function reactivateProduct(uint256 _productId) external onlyProductSeller(_productId) {
        Product storage product = products[_productId];
        require(!product.isActive, "Already active");
        require(product.quantity > 0, "No quantity available");
        product.isActive = true;
        emit ProductReactivated(_productId);
    }

    function updateProductDetails(
        uint256 _productId,
        string memory _name,
        string memory _description,
        uint256 _price,
        string memory _imageHash
    ) external onlyProductSeller(_productId) {
        Product storage product = products[_productId];
        product.name = _name;
        product.description = _description;
        product.price = _price;
        product.imageHash = _imageHash;
        emit ProductUpdated(_productId);
    }

    function emergencyWithdraw(uint256 amount) external onlyOwner {
        payable(owner).transfer(amount);
    }

    // ✅ View Functions

    function getActiveProducts() external view returns (Product[] memory) {
        uint256 count = 0;
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].isActive) count++;
        }

        Product[] memory active = new Product[](count);
        uint256 idx = 0;
        for (uint256 i = 1; i <= productCounter; i++) {
            if (products[i].isActive) {
                active[idx++] = products[i];
            }
        }
        return active;
    }

    function getAllProducts() external view returns (Product[] memory) {
        Product[] memory all = new Product[](productCounter);
        for (uint256 i = 1; i <= productCounter; i++) {
            all[i - 1] = products[i];
        }
        return all;
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

    function getAllOrdersOfProduct(uint256 _productId) external view returns (uint256[] memory) {
        return productOrders[_productId];
    }

    function getTotalSalesOfSeller(address _seller) external view returns (uint256 totalSales) {
        for (uint256 i = 1; i <= orderCounter; i++) {
            if (orders[i].seller == _seller && orders[i].status == OrderStatus.Delivered) {
                totalSales += orders[i].totalPrice;
            }
        }
    }

    receive() external payable {}
}

















