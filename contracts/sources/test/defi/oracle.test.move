#[test_only]
module suitears::oracle_tests {
  use std::type_name;

  use sui::clock;
  use sui::object;
  use sui::transfer;
  use sui::test_utils::assert_eq;
  use sui::test_scenario::{Self as test, next_tx, ctx};

  use suitears::owner;
  use suitears::supra_feed_test;
  use suitears::oracle::{Self, Oracle};
  use suitears::test_utils::{people, scenario};
  use suitears::pyth_feed_test::{Self, PythFeed};
  use suitears::switchboard_feed_test::{Self, SwitchboardFeed};

  struct CoinXOracle has drop {}
  struct CoinYOracle has drop {}
  
  const DEVIATION: u256 = 20000000000000000;
  const TIME_LIMIT: u64 = 100;
  
  #[test]
  fun test_oracle_flow() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>(), type_name::get<SwitchboardFeed>()],
        TIME_LIMIT,
        DEVIATION,
        ctx(test)
      );

      assert_eq(oracle::deviation(&oracle), DEVIATION);
      assert_eq(oracle::time_limit(&oracle), TIME_LIMIT);
      

      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);

      let request = oracle::request(&oracle);

      pyth_feed_test::report(&mut request, 50, 1500000000000000000000, 18);
      switchboard_feed_test::report(&mut request, 35, 1470000000000, 9);

      clock::increment_for_testing(&mut c, 130);

      let price = oracle::destroy_request(&oracle, request, &c);

      let (oracle_id, price, decimals, timestamp) = oracle::destroy_price(price);

      assert_eq(object::id(&oracle), oracle_id);
      assert_eq(price, 1500000000000000000000);
      assert_eq(decimals, 18);
      assert_eq(timestamp, 50);

      test::return_shared(oracle);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }


  #[test]
  #[expected_failure(abort_code = oracle::EOracleMustHaveFeeds)]
  fun test_new_no_feeds() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;


    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[],
        TIME_LIMIT,
        DEVIATION,
        ctx(test)
      );
      

      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };   
    test::end(scenario); 
  } 

  #[test]
  #[expected_failure(abort_code = oracle::EMustHavePositiveTimeLimit)]
  fun test_new_zero_time_limit() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;


    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>()],
        0,
        DEVIATION,
        ctx(test)
      );
      

      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };   
    test::end(scenario); 
  } 

  #[test]
  #[expected_failure(abort_code = oracle::EMustHavePositiveDeviation)]
  fun test_new_zero_deviation() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;


    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>()],
        1,
        0,
        ctx(test)
      );
      
      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };   
    test::end(scenario); 
  } 

  #[test]
  #[expected_failure(abort_code = oracle::ERequestAndOracleIdMismatch)]
  fun test_destroy_request_wrong_oracle() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));
      let cap_2 = owner::new(CoinYOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>()],
        1,
        1,
        ctx(test)
      );

      let oracle_2 = oracle::new(
        &mut cap_2,
        CoinYOracle {},
        vector[type_name::get<PythFeed>()],
        1,
        1,
        ctx(test)
      );
      
      oracle::share(oracle);
      oracle::share(oracle_2);

      transfer::public_transfer(cap, alice);
      transfer::public_transfer(cap_2, alice);
    };   

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);
      let oracle_2 = test::take_shared<Oracle<CoinYOracle>>(test);

      let request = oracle::request(&oracle);

      let price = oracle::destroy_request(&oracle_2, request, &c);

      let (_oracle_id, _price, _decimals, _timestamp) = oracle::destroy_price(price);

      test::return_shared(oracle);
      test::return_shared(oracle_2);
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);     
  }
 
  #[test]
  #[expected_failure(abort_code = oracle::EWrongNumberOfReports)]
  fun test_destroy_request_wrong_number_of_reports() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>(), type_name::get<SwitchboardFeed>()],
        1,
        1,
        ctx(test)
      );
      
      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };   

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);

      let request = oracle::request(&oracle);

      pyth_feed_test::report(&mut request, 50, 1500000000000000000000, 18);

      let price = oracle::destroy_request(&oracle, request, &c);

      let (_oracle_id, _price, _decimals, _timestamp) = oracle::destroy_price(price);

      test::return_shared(oracle);
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);     
  }

  #[test]
  #[expected_failure(abort_code = oracle::EInvalidReportFeeds)]
  fun test_destroy_request_invalid_report_feeds() {
   let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>(), type_name::get<SwitchboardFeed>()],
        1,
        1,
        ctx(test)
      );
      
      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };   

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);

      let request = oracle::request(&oracle);

      pyth_feed_test::report(&mut request, 50, 1500000000000000000000, 18);
      supra_feed_test::report(&mut request, 50, 1500000000000000000000, 18);

      let price = oracle::destroy_request(&oracle, request, &c);

      let (_oracle_id, _price, _decimals, _timestamp) = oracle::destroy_price(price);

      test::return_shared(oracle);
    };    

    clock::destroy_for_testing(c);
    test::end(scenario);     
  }

  #[test]
  #[expected_failure(abort_code = oracle::EStalePriceReport)]  
  fun test_destroy_request_stale_price() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>(), type_name::get<SwitchboardFeed>()],
        TIME_LIMIT,
        DEVIATION,
        ctx(test)
      );

      assert_eq(oracle::deviation(&oracle), DEVIATION);
      assert_eq(oracle::time_limit(&oracle), TIME_LIMIT);
      

      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);

      let request = oracle::request(&oracle);

      pyth_feed_test::report(&mut request, 50, 1500000000000000000000, 18);
      switchboard_feed_test::report(&mut request, 29, 1470000000000, 9);

      clock::increment_for_testing(&mut c, 130);

      let price = oracle::destroy_request(&oracle, request, &c);

      oracle::destroy_price(price);

      test::return_shared(oracle);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }  

  #[test]
  #[expected_failure(abort_code = oracle::EPriceCannotBeZero)]  
  fun test_report_zero_price() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>(), type_name::get<SwitchboardFeed>()],
        TIME_LIMIT,
        DEVIATION,
        ctx(test)
      );

      assert_eq(oracle::deviation(&oracle), DEVIATION);
      assert_eq(oracle::time_limit(&oracle), TIME_LIMIT);
      

      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);

      let request = oracle::request(&oracle);

      pyth_feed_test::report(&mut request, 50, 1500000000000000000000, 18);
      switchboard_feed_test::report(&mut request, 30, 0, 9);

      clock::increment_for_testing(&mut c, 130);

      let price = oracle::destroy_request(&oracle, request, &c);

      oracle::destroy_price(price);

      test::return_shared(oracle);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  } 

  #[test]
  #[expected_failure(abort_code = oracle::EPriceDeviationIsTooHigh)]  
  fun test_destroy_request_wrong_deviation() {
    let scenario = scenario();
    let (alice, _) = people();

    let test = &mut scenario;

    let c = clock::create_for_testing(ctx(test));

    next_tx(test, alice);  
    {
      let cap = owner::new(CoinXOracle {}, vector[], ctx(test));

      let oracle = oracle::new(
        &mut cap,
        CoinXOracle {},
        vector[type_name::get<PythFeed>(), type_name::get<SwitchboardFeed>()],
        TIME_LIMIT,
        DEVIATION,
        ctx(test)
      );

      assert_eq(oracle::deviation(&oracle), DEVIATION);
      assert_eq(oracle::time_limit(&oracle), TIME_LIMIT);
      

      oracle::share(oracle);

      transfer::public_transfer(cap, alice);
    };

    next_tx(test, alice);
    {
      let oracle = test::take_shared<Oracle<CoinXOracle>>(test);

      let request = oracle::request(&oracle);

      pyth_feed_test::report(&mut request, 50, 1500000000000000000000, 18);
      switchboard_feed_test::report(&mut request, 35, 1469999999999, 9);

      clock::increment_for_testing(&mut c, 130);

      let price = oracle::destroy_request(&oracle, request, &c);

      oracle::destroy_price(price);

      test::return_shared(oracle);
    };

    clock::destroy_for_testing(c);
    test::end(scenario);
  }

}

#[test_only]
module suitears::pyth_feed_test {

  use suitears::oracle::{Self, Request};

  struct PythFeed has drop {}

  public fun report(request: &mut Request, timestamp: u64, price: u128, decimals: u8) {
    oracle::report(request, PythFeed {}, timestamp, price, decimals);
  }
}

#[test_only]
module suitears::switchboard_feed_test {

  use suitears::oracle::{Self, Request};

  struct SwitchboardFeed has drop {}

  public fun report(request: &mut Request, timestamp: u64, price: u128, decimals: u8) {
    oracle::report(request, SwitchboardFeed {}, timestamp, price, decimals);
  }  
}

#[test_only]
module suitears::supra_feed_test {

  use suitears::oracle::{Self, Request};

  struct SupraFeed has drop {}

  public fun report(request: &mut Request, timestamp: u64, price: u128, decimals: u8) {
    oracle::report(request, SupraFeed {}, timestamp, price, decimals);
  }  
}