pragma solidity >=0.4.21 <0.6.0;

import "./TicketCreation_simplified.sol";
import "./erc721.sol";

contract TicketTransfer is TicketCreation, ERC721 {
    address payable contractDeployer;
    uint256 commissionFactor;

    constructor() public {
        contractDeployer = msg.sender;
        commissionFactor = 30;
    }

    event Transfer(address indexed _from, address indexed _to, uint256 indexed _ticketId);
    event Approval(address indexed _owner, address indexed _approved, uint256 indexed _ticketId);

    mapping (uint256 => uint256) public ticketIdToPending;
    mapping (uint256 => address) approvedBuyers;

    /* This modifier does not allow the msg.sender to be the seller */
    modifier notSeller(uint256 _ticketId){
        require(msg.sender != ticketsToOwner[_ticketId], "You are not the buyer.");
        _;
    }

    /* This modifier requires the ticket holder to be msg.sender */
    modifier ownsTicket(uint256 _ticketId){
        require(ticketsToOwner[_ticketId] == msg.sender, "You don't own the ticket.");
        _;
    }

    function getContractDeployer() public view returns (address) {
        return contractDeployer;
    }

    function getTicketCount() public view returns (uint256) {
        return tickets.length;
    }
    
    function balanceOf(address _owner) external view returns (uint256){
        return ownerToQuantity[_owner];
    }

    function ownerOf(uint256 _ticketId) external view returns (address){
        return ticketsToOwner[_ticketId];
    }

    function checkExpiry(uint256 _ticketId) external view returns (bool){
        if(now < tickets[_ticketId].expiry_date){
            return false;
        } else {
            return true;
        }
    }

    /* 1st TIME PURCHASE FROM PLATFORM - this is called when 1st time buyer presses the 'Purchase' button */
    function transferFrom(address payable _from, address _to, uint256 _ticketId) external payable notSeller(_ticketId) {
        require(now < tickets[_ticketId].expiry_date, "Ticket expired.");
        require(msg.value == (tickets[_ticketId].price)*1 ether, "Not enough money."); /* Requires buyer to pay the price of ticket */
        require(adToUserId[_to] > 0, "Please create an account first."); /* Requires user to have an account */
        _from.transfer((tickets[_ticketId].price)*1 ether);
        ticketsToOwner[_ticketId] = _to;
        ownerToQuantity[_from]--;
        ownerToQuantity[_to]++;
        emit Transfer(_from, _to, _ticketId);
    }

    /* Buyer revises the price */
    function priceRevise(uint256 _ticketId, uint16 _newPrice) external ownsTicket(_ticketId) returns(uint16){
        tickets[_ticketId].price = _newPrice;
        return _newPrice;
    }

    /* SECONDARY MARKET - a person looking to resell his/her ticket can only sell to a willing/approved buyer. This function is called by buyer. */
    function approve(address _approved, uint256 _ticketId) external payable notSeller(_ticketId){
        require(now < tickets[_ticketId].expiry_date, "Ticket expired.");
        require(adToUserId[msg.sender] > 0, "Please create an account first.");
        require(msg.value == (tickets[_ticketId].price) * 1 ether, "Not enough money."); /* Requires buyer to pay the price of ticket */
        approvedBuyers[_ticketId] = _approved; /* Buyer approves him/herself for the ticket, goes into the approved buyer mapping */
        ticketIdToPending[_ticketId] = msg.value; /* Buyer's money gets stored in the contract, so we store it in a temp mapping */
        emit Approval(ticketsToOwner[_ticketId], _approved, _ticketId);
    }

    /* Returning the approved buyer's address of a particular ticket ID */
    function getApprovedBuyer(uint256 _ticketId) external view returns(address){
        return approvedBuyers[_ticketId];
    }

    function payBack(address payable _to, uint256 _ticketId) external payable {
        _to.transfer(ticketIdToPending[_ticketId]);
        delete(ticketIdToPending[_ticketId]); /* Can be deleted as the mapping is no longer needed */
        delete(approvedBuyers[_ticketId]); /* Can be deleted as the mapping is no longer needed */
    }

    /* SECONDARY MARKET - after the buyer is approved, seller presses 'Sell' button, and then the ticket's ownership gets transferred. Seller also gets money from contract. */
    function resell(address _to, uint256 _ticketId) external payable ownsTicket(_ticketId) {
        require(adToUserId[msg.sender] > 0, "Please create an account first.");
        require(approvedBuyers[_ticketId] == _to, "This is not an approved buyer.");
        ticketsToOwner[_ticketId] = _to;
        ownerToQuantity[msg.sender]--;
        ownerToQuantity[_to]++;
        contractDeployer.transfer(ticketIdToPending[_ticketId]/commissionFactor);
        msg.sender.transfer(ticketIdToPending[_ticketId]/(commissionFactor/(commissionFactor-1)));
        delete(ticketIdToPending[_ticketId]); /* Can be deleted as the mapping is no longer needed */
        delete(approvedBuyers[_ticketId]); /* Can be deleted as the mapping is no longer needed */
        emit Transfer(msg.sender, _to, _ticketId);
        }
    }