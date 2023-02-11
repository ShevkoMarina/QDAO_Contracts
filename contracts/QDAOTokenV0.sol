import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./QDAOGovernorInterfaces.sol";

contract QDAOTokenV0 is ERC20 {

  constructor(address account) ERC20("DAOToken", "DAO") {
    _mint(account, 10000);
  }

  function getCurrentVotes(address account) external view returns (uint256 votes) {
      return balanceOf(account);
  }
}