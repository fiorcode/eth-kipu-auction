// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract EthKipuAuction {

    address public owner; // Owner
    uint256 public endAuctionDate; // Tentative completion date.

    struct Bid {
        address bidder;
        uint value;
    }

    mapping(address => uint256) private _bidsBalances; // Total amount of bids for each address.
    Bid private _highestBid; // Actual highest bid.
    Bid[] private _bids; // All bids receive.
    address[] private _bidders; // List of all bidders addresses.

    constructor() {
        owner = msg.sender; // Set the deployer as owner of the contract.
        endAuctionDate = block.timestamp + 7 days; // Set the tentative completion date.
        _highestBid = Bid(address(this), BASE_BID); // Sets an initial bid to start.
    }
    
    /**
     * MODIFIERS
     */

    /**
     * @dev Allows access to contract owner only.
     */
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner of this contract.");
        _;
    }

    /**
     * @dev Restrict access to the contract owner.
     */
    modifier notOwner() {
        require(msg.sender != owner, "Owner of this contract.");
        _;
    }


    /**
     * @dev Restrict access if auction is finish.
     */
    modifier auctionNotFinished() {
        require(block.timestamp <= endAuctionDate, "Auction finished.");
        _;
    }


    /**
     * @dev Restrict access if auction is not finish.
     */
    modifier auctionFinished() {
        require(block.timestamp > endAuctionDate, "Auction not finished yet.");
        _;
    }

    /**
     * PUBLIC FUNCTIONS
     */

    /**
    * @dev Function to receive bids.
    */
    function bid() public payable auctionNotFinished notOwner {
        require(msg.value > 0, "Bid must be greater than zero."); // Bid must be grater than zero.

        // Verify if bid is high enough.
        uint256 minRequiredBid = _highestBid.value + (_highestBid.value * MIN_BID_INCREMENT_PERCENTAGE / 100);
        require(msg.value >= minRequiredBid, "The bid must be at least 5% higher than the current bid.");

        Bid memory _bid = Bid(msg.sender, msg.value); // New Bid with sender data.
        _highestBid = _bid; // Set bid as highest.
        _bids.push(_bid); // Add bid to list of bids.

        uint256 bidderBalance = _bidsBalances[_bid.bidder];
        if (bidderBalance == 0) { // If bidder balance is zero it means its first offer.
            _bidders.push(address(msg.sender)); // Adds bidder address to bidders list.
        }
        _bidsBalances[_bid.bidder] = bidderBalance + _bid.value; // Updates balance of bids for sender.

       // Verify if auction has to be extended.
        if (endAuctionDate - block.timestamp <= BID_EXTENSION_TIME) {
            endAuctionDate = block.timestamp + BID_EXTENSION_TIME;
        }

        emit NewBid(_bid.bidder, _bid.value); 
    }

    /**
    * @dev Bidders can use this function to obtain their previous bids.
    */
    function retrievePreviousBids() public auctionNotFinished notOwner {
        uint256 balanceToRetrieve = _bidsBalances[msg.sender]; // Obtains the balance of the address.

        // If the address has the highest bid, we subtract it from its balance.
        if (_highestBid.bidder == msg.sender) {
            balanceToRetrieve -= _highestBid.value; 
        }

        // Verifies if there is balance to retrieve.
        require(balanceToRetrieve > 0, "No bids to retrieve.");

        (address(payable(msg.sender))).call{value: balanceToRetrieve}(""); // Send balance.
        _bidsBalances[msg.sender] = 0; // Updates balance of address to zero.

        emit BidsRetrieve(msg.sender, balanceToRetrieve);
    }

    /**
     * @dev Finishes the auction.
     */
    function finishAuction() public onlyOwner {
        endAuctionDate = block.timestamp; // Sets actual timestap as end auction date.
        emit AuctionFinished("Auction finshed by contract owner.");
    }

    /**
     * @dev Retrieve bids for those who not win.
     */
    function retrieveNotWinnerBids() public onlyOwner auctionFinished {
        uint256 biddersAddressesCount = _bidders.length; // Bidders addresses count.
        for (uint256 i = 0; i < biddersAddressesCount; i++) {

            address bidder = _bidders[i];
            uint256 balanceToRetrieve = _bidsBalances[bidder];

            // Checks if current bidder is the winnder, in that case substract the winner bid from their balance.
            if (bidder == _highestBid.bidder) {
                balanceToRetrieve = balanceToRetrieve - _highestBid.value;
            } 

            // Checks if there is balance to retrieve
            if (balanceToRetrieve > 0) {
                balanceToRetrieve = balanceToRetrieve - (balanceToRetrieve * COMMISSION_PERCENTAGE / 100); // Substract the commission from the balance to retrieve.

                (address(payable(msg.sender))).call{value: balanceToRetrieve}(""); // Send balance.
                _bidsBalances[bidder] = 0; // Updates balance of address to zero.

                emit BidsRetrieve(bidder, balanceToRetrieve);
            }
        }
    }

    /**
     * @dev Shows the highest bid.
     */
    function getHighestBid() public view returns (Bid memory) {
        return _highestBid;
    }

    /**
     * @dev Shows all bids.
     */
    function getBids() public view returns (Bid[] memory) {
        return _bids;
    }

    /**
     * @dev Shows the winner.
     */
    function getWinner() public view auctionFinished returns (Bid memory) {
        return _highestBid;
    }

    /**
     * EVENTS
     */

    /**
     * @dev Issued when a new valid offer is made.
     */
    event NewBid(address indexed bidder, uint amount);

        /**
     * @dev Issued when previous bids are retrieve.
     */
    event BidsRetrieve(address indexed bidder, uint amount);


    /**
     * @dev Issued when the auction ends.
     */
    event AuctionFinished(string message);


    /**
     * CONSTANTS
     */
    uint256 constant private BASE_BID = 100000 gwei;
    uint256 constant private MIN_BID_INCREMENT_PERCENTAGE = 5; 
    uint256 constant private BID_EXTENSION_TIME = 10 minutes; 
    uint256 constant private COMMISSION_PERCENTAGE = 2; 
}
