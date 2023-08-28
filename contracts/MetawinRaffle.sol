// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MetawinRaffle is ReentrancyGuard {
    using SafeMath for uint256;

    enum RaffleStatus {
        ONGOING,
        PENDING_COMPLETION,
        COMPLETE
    }

    //NFT raffle struct
    struct NftRaffle {
        address creator;
        address nftContractAddress;
        uint256 nftId;
        uint256 ticketPrice;
        uint256 totalPrice;
        uint256 minEntries;
        uint256 maxEntries;
        uint256 period;
        address winner;
        uint256 createdAt;
        RaffleStatus status;
        address[] tickets;
    }

    //Eth Raffle struct
    struct EthRaffle {
        address creator;
        uint256 rewardEth;
        uint256 ticketPrice;
        uint256 totalPrice;
        uint256 minEntries;
        uint256 maxEntries;
        uint256 period;
        uint256 numWinner;
        uint256[] rewardRate;
        uint256 createdAt;
        RaffleStatus status;
        address[] winners;
        address[] tickets;
    }

    //Contract owner address
    address public owner;

    uint16 public numNftRaffles;
    uint16 public numEthRaffles;

    address[] public adminList;
    uint256 public ethBalance;

    //NFT Raffles
    NftRaffle[] public nftRaffles;
    //Eth Raffles
    EthRaffle[] public ethRaffles;

    modifier onlyOwner {
        require(msg.sender == owner);
        _;
    }

    constructor() {
        owner = msg.sender;
        adminList.push(owner);
    }

    function addToAdminList(address _member) external onlyOwner returns (uint256) {
        uint256 length = adminList.length;
        bool flag;
        for (uint8 i = 0; i < length; i++) {
            if (adminList[i] == _member) {
                flag = true;
            }
        }

        require(flag == false);
        adminList.push(_member);

        return length;
    }

    function removeFromAdminList(address _member) external onlyOwner returns (uint256) {
        uint256 length = adminList.length;
        require(length > 1);

        uint256 index = length;
        for (uint8 i = 0; i < length; i++) {
            if (adminList[i] == _member) {
                index = i;
            }
        }

        require(index != length);

        if (index != length - 1) {
            adminList[index] = adminList[length - 1];
        }

        adminList.pop();

        return length;
    }

    //Create a new NFT raffle
    //nftContract.approve should be called before this function
    function createNftRaffle(
        IERC721 _nftContract,
        uint256 _nftId,
        uint256 _ticketPrice,
        uint256 _minTickets,
        uint256 _numTickets,
        uint256 _rafflePeriod,
        address _winner
    ) onlyOwner public returns (uint256) {
        //transfer the NFT from the raffle creator to this contract
        _nftContract.transferFrom(
            msg.sender,
            address(this),
            _nftId
        );

         //init tickets
        address[] memory _tickets;
        //create raffle
        NftRaffle memory _raffle = NftRaffle(
            msg.sender,
            address(_nftContract),
            _nftId,
            _ticketPrice,
            0,
            _minTickets,
            _numTickets,
            _rafflePeriod,
            _winner,
            block.timestamp,
            RaffleStatus.ONGOING,
            _tickets
        );

        //store raffel in state
        nftRaffles.push(_raffle);

        //increase nft raffle number
        numNftRaffles++;

        //emit event
        emit NftRaffleCreated(nftRaffles.length - 1, address(_nftContract), _nftId, _ticketPrice, _minTickets, _numTickets, _rafflePeriod);

        return nftRaffles.length;
    }

    //Cancel NFT Raffle
    function cancelNftRaffle(
        uint256 _raffleId
    ) onlyOwner public {
        require(
            block.timestamp > nftRaffles[_raffleId].createdAt + nftRaffles[_raffleId].period
        );

        require(
            nftRaffles[_raffleId].totalPrice == 0
        );

        //transfer the NFT from the contract to the raffle creator
        IERC721(nftRaffles[_raffleId].nftContractAddress).transferFrom(
            address(this),
            msg.sender,
            nftRaffles[_raffleId].nftId
        );

        nftRaffles[_raffleId].status = RaffleStatus.COMPLETE;

        emit NftRaffleCanceled(_raffleId);
    }

    //Create a new Eth Raffle
    function createEthRaffle(
        uint256 _rewardEth,
        uint256 _ticketPrice,
        uint256 _minTickets,
        uint256 _numTickets,
        uint256 _numWinner,
        uint256[] memory _rewardRate,
        uint256 _rafflePeriod,
        address _winner
    ) onlyOwner public payable returns (uint256) {
        require(msg.value == _rewardEth);

        address[] memory _tickets;
        address[] memory _winners = new address[](_numWinner);
        for (uint8 i = 0; i < _numWinner; i++) {
            _winners[i] = _winner;
        }

        EthRaffle memory _raffle = EthRaffle(
            msg.sender,
            _rewardEth,
            _ticketPrice,
            0,
            _minTickets,
            _numTickets,
            _rafflePeriod,
            _numWinner,
            _rewardRate,
            block.timestamp,
            RaffleStatus.ONGOING,
            _winners,
            _tickets
        );

        ethRaffles.push(_raffle);

        //increase eth raffle number
        numEthRaffles++;

        emit EthRaffleCreated(ethRaffles.length - 1, _rewardEth, _ticketPrice, _minTickets, _numTickets, _numWinner, _rafflePeriod);

        return ethRaffles.length;
    }

    //Cancel Eth raffle
    function cancelEthRaffle(uint256 _raffleId) onlyOwner public {
        require(
            block.timestamp > ethRaffles[_raffleId].createdAt + ethRaffles[_raffleId].period
        );

        require(
            ethRaffles[_raffleId].totalPrice == 0
        );

        (bool sent, ) = ethRaffles[_raffleId].creator.call{value: ethRaffles[_raffleId].rewardEth}("");
            require(sent);

        ethRaffles[_raffleId].status = RaffleStatus.COMPLETE;

        emit EthRaffleCanceled(_raffleId);
    }

    //enter a user in the draw for a given NFT raffle
    function enterNftRaffle(uint256 _raffleId, uint256 _tickets) public payable {
        require(
            uint256(nftRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING)
        );

        require(block.timestamp < (nftRaffles[_raffleId].createdAt + nftRaffles[_raffleId].period));

        require(
            _tickets.add(nftRaffles[_raffleId].tickets.length) <= nftRaffles[_raffleId].maxEntries
        );

        require(_tickets > 0);

        if(_tickets == 1) {
            require(msg.value == nftRaffles[_raffleId].ticketPrice);
        } else if(_tickets == 15) {
            require(msg.value == nftRaffles[_raffleId].ticketPrice.mul(5));
        } else if(_tickets == 35) {
            require(msg.value == nftRaffles[_raffleId].ticketPrice.mul(10));
        } else if(_tickets == 75) {
            require(msg.value == nftRaffles[_raffleId].ticketPrice.mul(20));
        } else if(_tickets == 155) {
            require(msg.value == nftRaffles[_raffleId].ticketPrice.mul(40));
        } else {
            require(msg.value == _tickets.mul(nftRaffles[_raffleId].ticketPrice));
        }

        //add _tickets
        for (uint256 i = 0; i < _tickets; i++) {
            nftRaffles[_raffleId].tickets.push(payable(msg.sender));
        }

        nftRaffles[_raffleId].totalPrice += msg.value;
        
        emit NftTicketPurchased(_raffleId, msg.sender, _tickets, block.timestamp);
    }

    function enterFreeNftRaffle(uint256 _raffleId, uint256 _tickets, address wlWallet) public onlyOwner {
        require(
            uint256(nftRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING)
        );

        require(block.timestamp < (nftRaffles[_raffleId].createdAt + nftRaffles[_raffleId].period));

        require(
            _tickets.add(nftRaffles[_raffleId].tickets.length) <= nftRaffles[_raffleId].maxEntries
        );

        require(_tickets > 0);

        //add _tickets
        for (uint256 i = 0; i < _tickets; i++) {
            nftRaffles[_raffleId].tickets.push(wlWallet);
        }
        
        emit NftTicketPurchased(_raffleId, wlWallet, _tickets, block.timestamp);
    }

    //enter a user in the draw for a given ETH raffle
    function enterEthRaffle(uint256 _raffleId, uint256 _tickets) public payable {
        require(
            uint256(ethRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING)
        );

        require(
            _tickets.add(ethRaffles[_raffleId].tickets.length) <= ethRaffles[_raffleId].maxEntries
        );
        
        require(_tickets > 0);

        for (uint256 i = 0; i < _tickets; i++) {
            ethRaffles[_raffleId].tickets.push(payable(msg.sender));
        }

        if(ethRaffles[_raffleId].maxEntries == 2) {
            require(msg.value == ethRaffles[_raffleId].ticketPrice);
            if (ethRaffles[_raffleId].tickets.length == 2) {
                chooseEthWinner(_raffleId);
            }
        } else {
            require(block.timestamp < (ethRaffles[_raffleId].createdAt + ethRaffles[_raffleId].period));

            if(_tickets == 1) {
                require(msg.value == ethRaffles[_raffleId].ticketPrice);
            } else if(_tickets == 15) {
                require(msg.value == ethRaffles[_raffleId].ticketPrice.mul(5));
            } else if(_tickets == 35) {
                require(msg.value == ethRaffles[_raffleId].ticketPrice.mul(10));
            } else if(_tickets == 75) {
                require(msg.value == ethRaffles[_raffleId].ticketPrice.mul(20));
            } else if(_tickets == 155) {
                require(msg.value == ethRaffles[_raffleId].ticketPrice.mul(40));
            } else {
                require(msg.value == _tickets.mul(nftRaffles[_raffleId].ticketPrice));
            }
        }

        ethRaffles[_raffleId].totalPrice += msg.value;
        
        emit EthTicketPurchased(_raffleId, msg.sender, _tickets, block.timestamp);
    }

    function enterFreeEthRaffle(uint256 _raffleId, uint256 _tickets, address wlWallet) public onlyOwner {
        require(
            uint256(ethRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING)
        );

        require(
            _tickets.add(ethRaffles[_raffleId].tickets.length) <= ethRaffles[_raffleId].maxEntries
        );
        
        require(_tickets > 0);

        for (uint256 i = 0; i < _tickets; i++) {
            ethRaffles[_raffleId].tickets.push(wlWallet);
        }
        
        emit EthTicketPurchased(_raffleId, wlWallet, _tickets, block.timestamp);
    }

    function chooseNftWinner(uint256 _raffleId) public returns (uint256) {
        NftRaffle storage raffle = nftRaffles[_raffleId];
        require(block.timestamp >= (raffle.createdAt + raffle.period));
        require(raffle.tickets.length >= raffle.minEntries);

        uint256 winnerIdx;
        if (raffle.winner == address(0)) {            
            winnerIdx = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.coinbase, msg.sender))) % raffle.tickets.length;
            //Input winnerIndex to raffle struct
            raffle.winner = raffle.tickets[winnerIdx];
        }

        //award winner
        IERC721(raffle.nftContractAddress).transferFrom(
            address(this),
            raffle.winner,
            raffle.nftId
        );

        raffle.status = RaffleStatus.COMPLETE;

        emit NftRaffleCompleted(
            _raffleId,
            raffle.winner
        );

        return winnerIdx;
    }

    function chooseEthWinner(uint256 _raffleId) public returns (uint256) {
        EthRaffle storage raffle = ethRaffles[_raffleId];
        uint256[] memory rate = raffle.rewardRate;

        if (ethRaffles[_raffleId].maxEntries != 2) {
            require(block.timestamp >= (raffle.createdAt + raffle.period));
        }
        require(raffle.tickets.length >= raffle.minEntries);

        uint256 winnerIdx;

        for (uint8 i = 0; i < raffle.numWinner; i++) {
            if (raffle.winners[i] == address(0)) {
                winnerIdx = uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.coinbase, msg.sender, i))) % raffle.tickets.length;
                raffle.winners[i] = raffle.tickets[winnerIdx];
            }

            (bool sent, ) = raffle.winners[i].call{value: (raffle.rewardEth.mul(rate[i]).div(100))}("");
            require(sent);
        }

        raffle.status = RaffleStatus.COMPLETE;

        emit EthRaffleCompleted(
            _raffleId,
            raffle.winners
        );

        return winnerIdx;
    }

    function getAllNftRaffles() external view returns (NftRaffle[] memory) {
        return nftRaffles;
    }

    function getAllEthRaffles() external view returns (EthRaffle[] memory) {
        return ethRaffles;
    }

    function extendNftRaffle (uint256 _raffleId, uint256 _period) public onlyOwner {
        require(
            uint256(nftRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING)
        );
        require(block.timestamp < (nftRaffles[_raffleId].createdAt + nftRaffles[_raffleId].period));

        nftRaffles[_raffleId].period += _period;

        emit NftRaffleExtended(_raffleId, nftRaffles[_raffleId].period);
    }

    function extendEthRaffle (uint256 _raffleId, uint256 _period) public onlyOwner {
        require(
            uint256(ethRaffles[_raffleId].status) == uint256(RaffleStatus.ONGOING)
        );
        require(block.timestamp < (ethRaffles[_raffleId].createdAt + ethRaffles[_raffleId].period));

        ethRaffles[_raffleId].period += _period;

        emit EthRaffleExtended(_raffleId, ethRaffles[_raffleId].period);
    }

    function depositFund (uint256 _amount) external payable nonReentrant {
        require((msg.value > 0 && msg.value == _amount));

        ethBalance += _amount;
    }

    function withdrawFund (uint256 _amount) external nonReentrant {
        require(address(this).balance >=_amount);

        (bool success, ) = msg.sender.call{value: _amount}("");
        require(success);

        ethBalance -= _amount;
    }

    event NftRaffleCreated(
        uint256 id,
        address indexed nftAddress,
        uint256 indexed nftId,
        uint256 ticketPrice,
        uint256 minEntries,
        uint256 maxEntries,
        uint256 period
    );
    event NftRaffleCanceled(uint256 id);
    event NftTicketPurchased(uint256 raffleId, address indexed buyer, uint256 numTickets, uint256 timestamp);
    event NftRaffleCompleted(uint256 id, address winner);
    event NftRaffleExtended(uint256 id, uint256 period);

    event EthRaffleCreated(
        uint256 id,
        uint256 reward,
        uint256 ticketPrice,
        uint256 minEntries,
        uint256 maxEntries,
        uint256 numWinner,
        uint256 period
    );
    event EthRaffleCanceled(uint256 id);
    event EthTicketPurchased(uint256 raffleId, address indexed buyer, uint256 numTickets, uint256 timestamp);
    event EthRaffleCompleted(uint256 id, address[] winners);
    event EthRaffleExtended(uint256 id, uint256 period);
}
