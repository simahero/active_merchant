require 'test_helper'
require 'json'

class SimplePayTest < Test::Unit::TestCase

  def setup
    @gateway = SimplePayGateway.new({
      :merchant_id  => 'PUBLICTESTHUF',
      :merchant_key => 'FxDa5w314kLlNseq2sKuVwaqZshZT5d6',
      :redirect_url => 'https://127.0.0.1',
      :timeout     => 1,
      :return_request => true
    })

    @merchant = 'PUBLICTESTHUF'

    @cardSecret = 'thesuperdupersecret'
    
    @credit_card = CreditCard.new(
      :number     => '4908366099900425',
      :month      => '10',
      :year       => '2021',
      :first_name => 'v2 AUTO',
      :last_name  => 'Tester',
      :verification_value  => '579'
    )

    @amount = 100

    @address = {
      :name =>  'myname',
      :company => 'company',
      :country => 'HU',
      :state => 'Budapest',
      :city => 'Budapest',
      :zip => '1111',
      :address1 => 'Address u.1',
      :address2 => 'Address u.2',
      :phone => '06301111111'
    }

    @options = {
      :email => 'test@email.hu',
      :address => @address
    }

  end

  def test_successful_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_response)

    response = @gateway.purchase(@amount, nil, @options)
    
    assert_success response
    assert response.params.key?('paymentUrl')
    assert_equal response.params['merchant'], @merchant 
    assert !response.params.key?('errorCodes')
    assert response.test?
  end

  def test_successful_auto_purchase
    @gateway.expects(:ssl_post).returns(successful_purchase_auto_response)

    response = @gateway.purchase(@amount, nil, @options)
    
    assert_success response
    assert response.params.key?('paymentUrl')
    assert_equal response.params['merchant'], @merchant 
    assert !response.params.key?('errorCodes')
    assert response.test?
  end

  def test_successful_purchase_with_secret
    @gateway.expects(:ssl_post).returns(successful_purchase_secret_response)

    options_with_secret = @options.clone
    options_with_secret[:cardSecret] = 'thesuperdupersecret'

    response = @gateway.purchase(@amount, nil, options_with_secret)
    assert_success response

    assert response.params.key?('paymentUrl')
    assert_equal response.params['merchant'], @merchant 
    assert !response.params.key?('errorCodes')
    assert response.test?
  end

  # def test_successful_recurring_purchase
  #   options_with_recurring = @options.clone
  #   options_with_recurring[:recurring] = {
  #     :times => 3,
  #     :until => "2030-12-01T18:00:00+02:00",
  #     :max_amount => 2000
  #   }
  #   response = @gateway.purchase(@amount, nil, options_with_recurring)

  #   assert response.params.key?('paymentUrl')
  #   assert_equal response.params['merchant'], @merchant 
  #   assert !response.params.key?('errorCodes')
  #   assert response.params.key?('tokens')
  #   assert response.params['tokens'].instance_of? Array
  #   assert_equal response.params['tokens'].length, 3
  #   assert response.test?
  # end

  # def test_succesfull_purchase_with_credit_card
  #   options_for_auto = @options.clone
    
  #   response = @gateway.purchase(@amount, @credit_card, options_for_auto)
    
  #   assert_equal response.params['merchant'], @merchant 
  #   assert !response.params.key?('errorCodes')
  #   assert response.test?
  # end

  # def test_failed_purchase
  #   response = @gateway.purchase(nil, nil, @options)
  #   assert_failure response
  # end

  #TODO OTP ERROR, No two step testing allowed
  # def test_successful_authorize
  #   options_for_auth = @options.clone
  #   options_for_auth[:order_id] = 'authorizationorderreffortesting'
  #   response = @gateway.authorize(@amount, options_for_auth)
  #   assert_success response

  #   assert response.params.key?('paymentUrl')
  #   assert response.test?
  # end

  #TODO OTP ERROR, No two step testing allowed
  # def test_failed_authorize
  #   response = @gateway.authorize(nil, @options)
  #   assert_failure response
  # end

  #TODO OTP ERROR, No two step testing allowed
  # def test_successful_capture
  #   options_for_capture = {
  #     :order_id => 'authorizationorderreffortesting',
  #     :original_total => @amount
  #   }
  #   response = @gateway.capture(1, options_for_capture)
  #   assert_success response
  # end

  #TODO OTP ERROR, No two step testing allowed
  # def test_failed_capture
  #   options_for_failed_capture = {
  #     #:order_id => 'thisorderidshouldnotexist',
  #     :original_total => @amount * 2
  #   }
  #   response = @gateway.capture(1, options_for_failed_capture)
  #   assert_failure response
  # end

  #TODO On FAIL: New :order_id should be created witha  sucessfull purchase
  # def test_successful_refund
  #   options_for_refund = {
  #     :order_id => 'AMSP202106252309552133',
  #   }
  #   response = @gateway.refund(1, options_for_refund)
  #   assert_success response
  # end

  # #TODO OTP ERROR, No two step testing allowed
  # def test_failed_refund
  #   options_for_failed_refund = {
  #     #missing order_id
  #   }
  #   response = @gateway.refund(@amount, options_for_failed_refund)
  #   assert_failure response
  # end

  #NO WAY OF TESTING IT WITHOUT SIMULATING A BROWSER
  # def test_succesfull_dorecurring
  #   options_with_token = @options.clone
  #   options_with_token[:recurring] = {
  #     :times => 1,
  #     :until => "2030-12-01T18:00:00+02:00",
  #     :maxAmount => 2000
  #   }
  #   token = @gateway.purchase(@amount, options_with_token).message['tokens'][0]

  #   options_for_dorecurring = @options.clone
  #   options_for_dorecurring
  #   response = @gateway.dorecurring(@amount, {
  #     :email => 'test@email.hu',
  #     :address => @address,
  #     :token => token,
  #     :three_ds_req_auth_method => '02',
  #     :type => 'MIT'
  #   })
  #   assert_success response
  # end

  #NO WAY OF TESTING IT
  # def test_unsuccesfull_dorecurring
  #   response = @gateway.dorecurring(@fail_options)
  #   assert_failure response
  # end

  private

  def pre_scrubbed
    '
      Run the remote tests for this gateway, and then put the contents of transcript.log here.
    '
  end

  def post_scrubbed
    '
      Put the scrubbed contents of transcript.log here after implementing your scrubbing function.
      Things to scrub:
        - Credit card number
        - CVV
        - Sensitive authentication details
    '
  end

  def successful_purchase_response
    '{"salt":"284Vgd2liJxElgLDFnwQ95QKp47eSi8d","merchant":"PUBLICTESTHUF","orderRef":"AMSP202106252322463392","currency":"HUF","transactionId":501284689,"timeout":"2021-06-25T23:23:46+02:00","total":100.0,"paymentUrl":"https://sandbox.simplepay.hu/pay/pay/pspHU/UYGSVcVcZK5k2aowEs2OTIFjy5cA0QOAwSILreOrkS-hLU5zD4"}'
  end

  def successful_purchase_auto_response
    '{"total"=>"100.0", "salt"=>"Ozbrw7faH9BoPkoOPaPaTytwDuPaBuOw", "orderRef"=>"AMSP20210720105114294", "merchant"=>"PUBLICTESTHUF", "currency"=>"HUF", "transactionId"=>"501387406"}'
  end

  def successful_purchase_secret_response
    '{"salt"=>"g98ntUKBnjHxGy6CsEMe8zu5STC1x7dH", "merchant"=>"PUBLICTESTHUF", "orderRef"=>"AMSP202107201051156509", "currency"=>"HUF", "transactionId"=>501387408, "timeout"=>"2021-07-20T11:01:15+02:00", "total"=>100.0, "paymentUrl"=>"https://sandbox.simplepay.hu/pay/pay/pspHU/ao4f0FGcbukhCcbs1UuOTnFj6d4BkQHlwSIxKXsZAEIwZxmzBj"}'
  end

  def failed_purchase_response
    '{"result"=>5100, "salt"=>"4oKcr60wN1noNENe2w22C6Nm89NwN3Xw", "orderRef"=>"AMSP202107201034238452", "errorCodes"=>["5100"], "merchant"=>"PUBLICTESTHUF"}'
  end

  def successful_authorize_response; end

  def failed_authorize_response
    '{"errorCodes"=>[5308], "salt"=>"Ys9KtZb5je5sQUykiW7LozdIes8iMCIJ", "merchant"=>"PUBLICTESTHUF", "orderRef"=>"AMSP20210720103710376", "currency"=>"HUF", "total"=>0.0}'
  end

  def successful_capture_response; end

  def failed_capture_response
    '{"errorCodes"=>[5111], "salt"=>"UOOQqKjs6is92aG8GoyHdCKelzRwhAVh", "merchant"=>"PUBLICTESTHUF", "currency"=>"HUF"}'
  end

  def successful_refund_response; end

  def failed_refund_response
    '{"errorCodes"=>[5111], "salt"=>"LEGhkUZMkEqoylHdXOzx1g1nHEdFbXGz"}'
  end

  def successful_void_response; end

  def failed_void_response; end
end
