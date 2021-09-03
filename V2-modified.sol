// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "./Pay.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol";
interface IUniswapV2Router {
  function getAmountsOut(uint256 amountIn, address[] memory path)
    external
    view
    returns (uint256[] memory amounts);
  
  function swapExactTokensForTokens(
  
    //amount of tokens we are sending in
    uint256 amountIn,
    //the minimum amount of tokens we want out of the trade
    uint256 amountOutMin,
    //list of token addresses we are going to trade in.  this is necessary to calculate amounts
    address[] calldata path,
    //this is the address we are going to send the output tokens to
    address to,
    //the last time that the trade is valid for
    uint256 deadline
  ) external returns (uint256[] memory amounts);
}

interface IUniswapV2Pair {
  function token0() external view returns (address);
  function token1() external view returns (address);
  function swap(
    uint256 amount0Out,
    uint256 amount1Out,
    address to,
    bytes calldata data
  ) external;
}

interface IUniswapV2Factory {
  function getPair(address token0, address token1) external returns (address);
}



contract tokenSwap {
    
    //address of the uniswap v2 router
    address private constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    
    //address of WETH token.  This is needed because some times it is better to trade through WETH.  
    //you might get a better price using WETH.  
    //example trading from token A to WETH then WETH to token B might result in a better price
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    

    //this swap function is used to trade from one token to another
    //the inputs are self explainatory
    //token in = the token address you want to trade out of
    //token out = the token address you want as the output of this trade
    //amount in = the amount of tokens you are sending in
    //amount out Min = the minimum amount of tokens you want out of the trade
    //to = the address you want the tokens to be sent to
    
   function swap(address _tokenIn, address _tokenOut, uint256 _amountIn, uint256 _amountOutMin, address _to) external {
      
    //first we need to transfer the amount in tokens from the msg.sender to this contract
    //this contract will have the amount of in tokens
    IERC20(_tokenIn).transferFrom(msg.sender, address(this), _amountIn);
    
    //next we need to allow the uniswapv2 router to spend the token we just sent to this contract
    //by calling IERC20 approve you allow the uniswap contract to spend the tokens in this contract 
    IERC20(_tokenIn).approve(UNISWAP_V2_ROUTER, _amountIn);

    //path is an array of addresses.
    //this path array will have 3 addresses [tokenIn, WETH, tokenOut]
    //the if statement below takes into account if token in or token out is WETH.  then the path is only 2 addresses
    address[] memory path;
    if (_tokenIn == WETH || _tokenOut == WETH) {
      path = new address[](2);
      path[0] = _tokenIn;
      path[1] = _tokenOut;
    } else {
      path = new address[](3);
      path[0] = _tokenIn;
      path[1] = WETH;
      path[2] = _tokenOut;
    }
        //then we will call swapExactTokensForTokens
        //for the deadline we will pass in block.timestamp
        //the deadline is the latest time the trade is valid for
        IUniswapV2Router(UNISWAP_V2_ROUTER).swapExactTokensForTokens(_amountIn, _amountOutMin, path, _to, block.timestamp);
    }
    
       //this function will return the minimum amount from a swap
       //input the 3 parameters below and it will return the minimum amount out
       //this is needed for the swap function above
     function getAmountOutMin(address _tokenIn, address _tokenOut, uint256 _amountIn) external view returns (uint256) {

       //path is an array of addresses.
       //this path array will have 3 addresses [tokenIn, WETH, tokenOut]
       //the if statement below takes into account if token in or token out is WETH.  then the path is only 2 addresses
        address[] memory path;
        if (_tokenIn == WETH || _tokenOut == WETH) {
            path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;
        } else {
            path = new address[](3);
            path[0] = _tokenIn;
            path[1] = WETH;
            path[2] = _tokenOut;
        }
        
        uint256[] memory amountOutMins = IUniswapV2Router(UNISWAP_V2_ROUTER).getAmountsOut(_amountIn, path);
        return amountOutMins[path.length -1];  
    }  
}
contract Market is tokenSwap{
    using SafeMath for uint;
    struct Asset{
        uint id;
        uint vendor_id;
        uint price;
    }
    event listAsset(uint id, uint price);
    Pay token;
    tokenSwap D;
    address internal constant UNISWAP_ROUTER_ADDRESS = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D; //ropsten adddress
    IUniswapV2Router02 public uniswapRouter = IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    address private pay = 0xEb306583b6ce2b4559740F822272d3E85bf67777; //ropsten address
    address private usdt = 0xAa0dcE5ec02e54F9FA368Fc50F3bEa9aef8F52c4; //ropsten address
    event feeChange(uint id, uint fee);
    struct Vendor{
        string name;
        uint id;
        address vendor_ad;
        uint platform_fee;
    }
    mapping(address => Vendor) public vendor;
    mapping(address => Asset) public order;
    Vendor [] public vendors;
    Asset [] public assets;
    modifier onlyVendor{
        require(vendor[msg.sender].id != 0, "Only vendors can change fee");
        _;
    }
    constructor(string[] memory names, address[] memory _vendors, uint[] memory fee){
        for(uint i = 0; i <vendors.length; i++ ){
            vendors.push(Vendor({
                name: names[i],
                id: i++,
                vendor_ad: _vendors[i],
                platform_fee: fee[i]
            }));
        }
    }
    function changeFee(uint id,uint fee) onlyVendor public{
        vendors[id].platform_fee = fee;
        emit feeChange(id, fee);
    }
    function addAsset(uint _id, uint _vendor_id, uint _price) public{
        assets.push(Asset({
            id: _id,
            vendor_id: _vendor_id ,
            price: _price
        }));
        emit listAsset(_id, _price);
    }
    function buyToken(uint _amount) public payable returns(bool success){
        token.transfer(msg.sender, _amount);
        return true;
    }
    function buyAsset(uint _id) external payable{
        order[msg.sender] = assets[_id];
        uint k = assets[_id].vendor_id;
        uint platformFee = assets[_id].price.mul(vendors[k].platform_fee).div(100);
        token.transferFrom(msg.sender, address(this), platformFee);
        uint amountOutMin = D.getAmountOutMin(pay, usdt, assets[_id].price.sub(platformFee));
        D.swap(pay,usdt, assets[_id].price.sub(platformFee), amountOutMin, vendors[k].vendor_ad);
    }
}