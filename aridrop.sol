// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;
interface IUST {
    function airdrop(uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
contract UST_airdrop{
    uint256 public aridropamount=50*1e6;
    address immutable public UST=0x40702Ced313Fd785D27c465A734c26861D481b68; 
    address public owner;
    bool public PrivateMode = false;
    constructor(){
        owner=msg.sender;
    }

    function airdrop() public {
        require(!PrivateMode || msg.sender == owner);
        uint256 amount=IUST(UST).balanceOf(address(this));
        if(amount>=aridropamount){
        IUST(UST).airdrop(aridropamount);}
        else {
        IUST(UST).airdrop(amount);  
        }
    }

    function setOwner(address new_owner) public {
        require(msg.sender == owner);
        owner = new_owner;
    }

    function setMode() public {
        require(msg.sender == owner);
        PrivateMode = !PrivateMode;
    }

    function setaridropamount(uint256 new_amount) public {
        require(msg.sender == owner);
        aridropamount=new_amount;   
    }
}
