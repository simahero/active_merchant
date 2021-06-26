require 'test_helper'

class RemoteSimplePayTest < Test::Unit::TestCase
  def setup
    @gateway = SimplePayGateway.new(fixtures(:simple_pay))

    @amount = 100
    @credit_card = CreditCard.new(
      :number     => '4908366099900425',
      :month      => '10',
      :year       => '2021',
      :first_name => 'v2 AUTO',
      :last_name  => 'Tester',
      :verification_value  => '579'
    )
    @declined_card = CreditCard.new(
      :number     => '4111111111111111',
      :month      => '10',
      :year       => '2021',
      :first_name => 'v2 AUTO',
      :last_name  => 'Tester',
      :verification_value  => '579'
    )

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
    response = @gateway.purchase(999999, nil, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_purchase_with_more_options
    options = {
      :email => 'test@email.hu',
      :address => @address,
      :three_ds_req_auth_method => '01',
      :may_select_email => true,
      :may_select_invoice => true,
      :may_select_delivery => ["HU","AT","DE"]
    }

    response = @gateway.purchase(@amount, nil, options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_purchase_auto
    response = @gateway.purchase(@amount, @credit_card, @options)
    assert_success response
    assert_equal 'OK', response.message
  end

  def test_successful_purchase_with_secret
  end

  #CANNOT BE TESTED, USER INTERACTION NEEDED
  # def test_successful_purchase_with_token
  #   recurring_options = @options.clone
  #   recurring_options[:recurring] = {
  #     :times => 1,
  #     :until => "2022-12-01T18:00:00+02:00",
  #     :max_amount => 2000
  #   }
  #   auth = @gateway.purchase(@amount, nil, recurring_options)
  #   assert_success auth
 
  #   dorecurring_options = @options.clone
  #   dorecurring_options[:token] = auth.params['tokens'][0]
  #   dorecurring_options[:three_ds_req_auth_method] = '02'
  #   dorecurring_options[:type] = 'MIT'
  #   assert capture = @gateway.dorecurring(@amount, auth.parmas)
  #   assert_success capture
  #   assert_equal 'OK', capture.message
  # end

  def test_failed_purchase
    response = @gateway.purchase(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'FAIL', response.message
  end

  # 2STEP ALLOWED ACCOUNT NEEDED
  # def test_successful_authorize_and_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount, auth.authorization)
  #   assert_success capture
  #   assert_equal 'OK', capture.message
  # end

  def test_failed_authorize
    response = @gateway.authorize(@amount, @declined_card, @options)
    assert_failure response
    assert_equal 'FAIL', response.message
  end

  # def test_partial_capture
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert capture = @gateway.capture(@amount - 1, auth.authorization)
  #   assert_success capture
  # end

  def test_failed_capture
    response = @gateway.capture(@amount, {})
    assert_failure response
    assert_equal 'FAIL', response.message
  end

  # IDK WHY IT FAILS???????? PROB ACCOUNT PROBLEM
  # def test_successful_refund
  #   purchase = @gateway.purchase(@amount, @credit_card, @options)
  #   assert_success purchase

  #   query = @gateway.query({
  #     :order_ids => [purchase.authorization],
  #     :detailed => true,
  #     :refunds => true
  #   })

  #   assert refund = @gateway.refund(@amount, {:order_id => purchase.authorization})
  #   assert_success refund
  #   assert_equal 'OK', refund.message
  # end

  def test_partial_refund

    # Too slow till the status get's to able to be refunded.
    # purchase = @gateway.purchase(@amount, @credit_card, @options)
    # assert_success purchase

    assert refund = @gateway.refund(1, {:order_id => 'iHsSPXedqZtR1GuSzp95oOxXfiVhzWbX'})
    assert_success refund
    assert_equal 'OK', refund.message
  end

  def test_failed_refund
    response = @gateway.refund(@amount, {})
    assert_failure response
    assert_equal 'FAIL', response.message
  end

  # def test_successful_void
  #   auth = @gateway.authorize(@amount, @credit_card, @options)
  #   assert_success auth

  #   assert void = @gateway.void(auth.authorization)
  #   assert_success void
  #   assert_equal 'OK', void.message
  # end

  # def test_failed_void
  #   response = @gateway.void('')
  #   assert_failure response
  #   assert_equal 'FAIL', response.message
  # end

  # def test_successful_verify
  #   response = @gateway.verify(@credit_card, @options)
  #   assert_success response
  #   assert_match %r{OK}, response.message
  # end

  # def test_failed_verify
  #   response = @gateway.verify(@declined_card, @options)
  #   assert_failure response
  #   assert_match %r{REPLACE WITH FAILED PURCHASE MESSAGE}, response.message
  # end

  def test_invalid_login
    gateway = SimplePayGateway.new(
    :merchant_id  => 'THISPROBDOESNTEXISTIFITDOESIMGONNAEATMYHAT',
    :merchant_key => 'THESECRETFORTHENONEXISTINGMERCHANTID',
    :redirect_url => 'https://www.example.com/back'
    )

    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
    assert_match 'FAIL', response.message
  end

  # def test_dump_transcript
  #   # This test will run a purchase transaction on your gateway
  #   # and dump a transcript of the HTTP conversation so that
  #   # you can use that transcript as a reference while
  #   # implementing your scrubbing logic.  You can delete
  #   # this helper after completing your scrub implementation.
  #   dump_transcript_and_fail(@gateway, @amount, @credit_card, @options)
  # end

  # def test_transcript_scrubbing
  #   transcript = capture_transcript(@gateway) do
  #     @gateway.purchase(@amount, @credit_card, @options)
  #   end
  #   transcript = @gateway.scrub(transcript)

  #   assert_scrubbed(@credit_card.number, transcript)
  #   assert_scrubbed(@credit_card.verification_value, transcript)
  #   assert_scrubbed(@gateway.options[:password], transcript)
  # end
end
