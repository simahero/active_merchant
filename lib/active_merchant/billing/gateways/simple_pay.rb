module ActiveMerchant #:nodoc:
  module Billing #:nodoc:
    class SimplePayGateway < Gateway

      require 'json'
      require 'base64'
      require 'openssl'

      self.test_url = {
        :start       => 'https://sandbox.simplepay.hu/payment/v2/start',
        :authorize   => 'https://sandbox.simplepay.hu/payment/v2/start',
        :capture     => 'https://sandbox.simplepay.hu/payment/v2/finish',
        :refund      => 'https://sandbox.simplepay.hu/payment/v2/refund',
        :query       => 'https://sandbox.simplepay.hu/payment/v2/query',

        :auto        => 'https://sandbox.simplepay.hu/pay/pay/auto/pspHU',
        
        :do          => 'https://sandbox.simplepay.hu/payment/v2/do',
        :dorecurring => 'https://sandbox.simplepay.hu/payment/v2/dorecurring',
        :cardquery   => 'https://sandbox.simplepay.hu/payment/v2/cardquery',
        :cardcancel  => 'https://sandbox.simplepay.hu/payment/v2/cardcancel',
        :tokenquery  => 'https://sandbox.simplepay.hu/payment/v2/tokenquery',
        :tokencancel => 'https://sandbox.simplepay.hu/payment/v2/tokencancel'
      }
      self.live_url = {
        :start       => 'https://secure.simplepay.hu/payment/v2/start',
        :authorize   => 'https://secure.simplepay.hu/payment/v2/start',
        :capture     => 'https://secure.simplepay.hu/payment/v2/finish',
        :refund      => 'https://secure.simplepay.hu/payment/v2/refund',
        :query       => 'https://secure.simplepay.hu/payment/v2/query',

        :auto        => 'https://secure.simplepay.hu/pay/pay/auto/pspHU',
        
        :do          => 'https://secure.simplepay.hu/payment/v2/do',
        :dorecurring => 'https://secure.simplepay.hu/payment/v2/dorecurring',
        :cardquery   => 'https://secure.simplepay.hu/payment/v2/cardquery',
        :cardcancel  => 'https://secure.simplepay.hu/payment/v2/cardcancel',
        :tokenquery  => 'https://secure.simplepay.hu/payment/v2/tokenquery',
        :tokencancel => 'https://secure.simplepay.hu/payment/v2/tokencancel'
      }

      self.supported_countries = ['HU']
      self.default_currency = 'HUF'
      self.money_format = 'cents'
      self.supported_cardtypes = %i[visa master maestro american_express]
      self.homepage_url = 'https://simplepay.hu/'
      self.display_name = 'Simple Pay'

      class_attribute :sdk_version, :language, :allowed_ip
      self.sdk_version = 'SimplePayV2.1_Payment_PHP_SDK_2.0.7_190701:dd236896400d7463677a82a47f53e36e'
      self.language = 'HU'
      self.allowed_ip = '94.199.53.96'

      STANDARD_ERROR_CODE_MAPPING = {
        '0'    => 'Sikeres művelet',
        '999'  => 'Általános hibakód.',
        '1529' => 'Belső hiba',
        '2003' => 'Megadott jelszó érvénytelen',
        '2004' => 'Általános hibakód',
        '2006' => 'Megadott kereskedő nem létezik',
        '2008' => 'Megadott e-mail nem megfelelő',
        '2010' => 'Megadott tranzakcióazonosító nem megfelelő',
        '2013' => 'Nincs elég fedezet a kártyán',
        '2016' => 'A felhasználó megszakította a fizetés',
        '2019' => 'Időtúllépés az elfogadói kommunikációban',
        '2021' => 'Kétfaktoros hitelesítés (SCA) szükséges',
        '2063' => 'Kártya inaktív',
        '2064' => 'Hibás bankkártya adatok',
        '2065' => 'Megadott kártya bevonása szükséges',
        '2066' => 'Kártya nem terhelhető / limittúllépés miatt',
        '2068' => 'Érvénytelen 3DS adat / kártyakibocsátó által elutasított 3DS authentikáció',
        '2070' => 'Invalid kártyatípus',
        '2071' => 'Hibás bankkártya adatok',
        '2072' => 'Kártya lejárat nem megfelelő',
        '2073' => 'A megadott CVC nem megfelelő',
        '2074' => 'Kártyabirtokos neve több, nint 32 karakter',
        '2078' => 'Kártyakibocsátó bank nem tudja megmondani a kártyatulajdonosnak a hiba okát',
        '2079' => 'A routingnak megfelelő elfogadók nem érhetőek el',
        '2999' => 'Belső hiba',
        '3002' => '3DS folyamat hiba',
        '3003' => '3DS folyamat hiba',
        '3004' => 'Redirect 3DS challenge folyamán',
        '3005' => '3D secure azonosítás szükséges',
        '3012' => '3D Secure folyamat megszakítása. pl. nem 3DS képes bankkártya miatt',
        '5000' => 'Általános hibakód.',
        '5010' => 'A fiók nem található.',
        '5011' => 'A tranzakció nem található',
        '5012' => 'Account nem egyezik meg',
        '5013' => 'A tranzakció már létezik (és nincs újraindíthatóként jelölve).',
        '5014' => 'A tranzakció nem megfelelő típusú',
        '5015' => 'A tranzakció éppen fizetés alatt',
        '5016' => 'Tranzakció időtúllépés (elfogadói/acquirer oldal felől érkező kérés során).',
        '5017' => 'A tranzakció meg lett szakítva (elfogadói/acquirer oldal felől érkező kérés során).',
        '5018' => 'A tranzakció már kifizetésre került (így újabb művelet nem kezdeményezhető).',
        '5020' => 'A kérésben megadott érték vagy az eredeti tranzakcióösszeg ("originalTotal") ellenőrzése sikertelen',
        '5021' => 'A tranzakció már lezárásra került (így újabb Finish művelet nem kezdeményezhető).',
        '5022' => 'A tranzakció nem a kéréshez elvárt állapotban van.',
        '5023' => 'Ismeretlen fiók devizanem.',
        '5026' => 'Tranzakció letiltva (sikertelen fraud-vizsgálat következtében).',
        '5030' => 'A művelet nem engedélyezett',
        '5040' => 'Tárolt kártya nem található',
        '5041' => 'Tárolt kártya lejárt',
        '5042' => 'Tárolt kártya inaktíválva',
        '5044' => 'Recurring nincs engedélyezve',
        '5048' => 'Recurring until szükséges',
        '5049' => 'Recurring until eltér',
        '5071' => 'Tárolt kártya érvénytelen hossz',
        '5072' => 'Tárolt kártya érvénytelen művelet',
        '5081' => 'Recurring token nem található',
        '5082' => 'Recurring token használatban',
        '5083' => 'Token times szükséges',
        '5084' => 'Token times túl nagy',
        '5085' => 'Token until szükséges',
        '5086' => 'Token until túl nagy',
        '5087' => 'Token maxAmount szükséges',
        '5088' => 'Token maxAmount túl nagy',
        '5089' => 'Recurring és oneclick regisztráció egyszerre nem indítható egy tranzakcióban',
        '5090' => 'Recurring token szükséges',
        '5091' => 'Recurring token inaktív',
        '5092' => 'Recurring token lejárt',
        '5093' => 'Recurring account eltérés',
        '5110' => 'Nem megfelelő visszatérítendő összeg. (Az opcionálisan megadható "refundTotal" érték nem lehet negatív és a jelenleg összesen még visszatéríthető összeget nem lépheti túl.)',
        '5111' => 'Az orderRef és a transactionId közül az egyik küldése kötelező',
        '5113' => 'A hívó kliensprogram megnevezése,verziószáma ("sdkVersion") kötelező.',
        '5201' => 'A kereskedői fiók azonosítója ("merchant") hiányzik.',
        '5213' => 'A kereskedői tranzakcióazonosító ("orderRef") hiányzik.',
        '5216' => 'Érvénytelen szállítási összeg',
        '5219' => 'Email cím ("customerEmail") hiányzik, vagy nem email fotmátumu.',
        '5220' => 'A tranzakció nyelve ("language") nem megfelelő',
        '5223' => 'A tranzakció pénzneme ("currency") nem megfelelő, vagy hiányzik.',
        '5302' => 'Nem megfelelő aláírás (signature) a beérkező kérésben. (A kereskedői API-ra érkező hívás aláírás-ellenőrzése sikertelen.)',
        '5303' => 'Nem megfelelő aláírás (signature) a beérkező kérésben. (A kereskedői API-ra érkező hívás aláírás-ellenőrzése sikertelen.)',
        '5304' => 'Időtúllépés miatt sikertelen aszinkron hívás.',
        '5305' => 'Sikertelen tranzakcióküldés a fizetési rendszer (elfogadói/acquirer oldal) felé.',
        '5306' => 'Sikertelen tranzakciólétrehozás',
        '5307' => 'A kérésben megadott devizanem ("currency") nem egyezik a fiókhoz beállítottal.',
        '5308' => 'A kérésben érkező kétlépcsős tranzakcióindítás nem engedélyezett a kereskedői fiókon',
        '5309' => 'Számlázási adatokban a címzett hiányzik ("name" természetes személy esetén, "company"jogi személy esetén).',
        '5310' => 'Számlázási adatokban a város kötelező.',
        '5311' => 'Számlázási adatokban az irányítószám kötelező.',
        '5312' => 'Számlázási adatokban a cím első sora kötelező.',
        '5313' => 'A megvásárlandó termékek listájában ("items") a termék neve ("title") kötelező.',
        '5314' => 'A megvásárlandó termékek listájában ("items") a termék egységára ("price") kötelező.',
        '5315' => 'A megvásárlandó termékek listájában ("items") a rendelt mennyiség ("amount") kötelezőpozitív egész szám.',
        '5316' => 'Szállítási adatokban a címzett kötelező ("name" természetes személy esetén, "company" jogi személy esetén).',
        '5317' => 'Szállítási adatokban a város kötelező.',
        '5318' => 'Szállítási adatokban az irányítószám kötelező.',
        '5319' => 'Szállítási adatokban a cím első sora kötelező.',
        '5320' => 'A hívó kliensprogram megnevezése,verziószáma ("sdkVersion") kötelező.',
        '5321' => 'Formátumhiba',
        '5322' => 'Érvénytelen ország',
        '5324' => 'Termékek listája ("items"), vagy tranzakciófőösszeg ("total") szükséges',
        '5325' => 'A visszairányítást vezérlő mezők közül legalább az egyik küldendő {(a) "url" - minden esetrevagy (b) "urls": különböző eseményekre egyenként megadhatóan}.',
        '5323' => 'Nem megfelelő véglegesítendő tranzakcióösszeg. (Az opcionálisan megadható "approveTotal" érték 0 és az eredeti tranzakció összege közötti érték kell legyen; Finish művelet során.)',
        '5326' => 'Hiányzó cardId',
        '5327' => 'Lekérdezendő kereskedői tranzakcióazonosítók ("orderRefs") maximális számának (50) túllépése.',
        '5328' => 'Lekérdezendő SimplePay tranzakcióazonosítók ("transactionIds") maximális számának (50) túllépése.',
        '5329' => 'Lekérdezendő tranzakcióindítás időszakában "from" az "until" időpontot meg kell előzze.',
        '5330' => 'Lekérdezendő tranzakcióindítás időszakában "from" és "until" együttesen adandó meg.',
        '5331' => 'Invaid API típus / A tranzakció nem V1, V2 vagy MW-s1',
        '5333' => 'Hiányzó tranzakció azonosító',
        '5337' => 'Hiba összetett adat szöveges formába írásakor.',
        '5339' => 'Lekérdezendő tranzakciókhoz tartozóan vagy az indítás időszaka ("from" és "until") vagy az azonosítólista ("orderRefs" vagy "transactionIds") megadandó.',
        '5343' => 'Invalid státusz kétlépcsős feloldáshoz',
        '5344' => 'Invalid státuz kétlépcsős lezáráshoz',
        '5345' => 'Áfa összege kisebb, mint 0',
        '5349' => 'A tranzakció nem engedélyezett az elszámoló fiókon (AMEX)',
        '5401' => 'Érvénytelen salt, nem 32-64 hosszú',
        '5413' => 'Létrejött utalási tranzakció',
        '5501' => 'Browser accept hiányzik',
        '5502' => 'Browser agent hiányzik',
        '5503' => 'Browser ip hiányzik',
        '5504' => 'Browser java hiányzik',
        '5505' => 'Browser lang hiányzik',
        '5506' => 'Browser color hiányzik',
        '5507' => 'Browser height hiányzik',
        '5508' => 'Browser width hiányzik',
        '5509' => 'Browser tz hiányzik',
        '5511' => 'Invalid browser accept',
        '5512' => 'Invalid browser agent',
        '5513' => 'Invalid browser IP',
        '5514' => 'Invalid browser java',
        '5515' => 'Invalid browser lang',
        '5516' => 'Invalid browser color',
        '5517' => 'Invalid browser height',
        '5518' => 'Invalid browser width',
        '5519' => 'Invalid browser tz',
        '5530' => 'Érvénytelen type',
        '5550' => 'Invalid JWT',
        '5813' => 'Kártya elutasítva',
      }

      def initialize(options = {})
        requires!(options, :merchant_id, :merchant_key, :redirect_url)
        if ['HUF', 'EUR', 'USD'].include? options[:currency]
          self.default_currency = options[:currency]
        end
        if !options.key?(:redirect_url)
          requires!(options, :urls)
          requires!(options[:urls], :success, :fail, :cancel, :timeout)
        end
        if !options.key?(:urls)
          requires!(options, :redirect_url)
        end
        super
      end

      def purchase(amount, credit_card, options = {})
        post = {}
        post[:total] = amount
        if credit_card == nil
          generate_post_data(:start, post, options)
          commit(:start, JSON[post])
        else
          add_credit_card_data(post, credit_card)
          generate_post_data(:auto, post, options)
          commit(:auto, JSON[post])
        end 
      end

      #credit card?
      def authorize(amount, credit_card, options = {})
        post = {}
        post[:total] = amount
        if credit_card
          add_credit_card_data(post, credit_card)
        end
        generate_post_data(:authorize, post, options)
        commit(:authorize, JSON[post])
      end

      def capture(amount, options = {})
        post = {}
        post[:approveTotal] = amount
        generate_post_data(:capture, post, options)
        commit(:capture, JSON[post])
      end

      def refund(amount, options = {})
        post = {}
        post[:refundTotal] = amount
        generate_post_data(:refund, post, options)
        commit(:refund, JSON[post])
      end

      def query(options = {})
        post = {}
        generate_post_data(:query, post, options)
        commit(:query, JSON[post])
      end

      def void(authorization, options = {})
        commit('void', post)
      end

      def verify(credit_card, options = {})
        MultiResponse.run(:use_first_response) do |r|
          r.process { authorize(100, credit_card, options) }
          r.process(:ignore_result) { void(r.authorization, options) }
        end
      end

      def do(options = {})
        post = {}
        generate_post_data(:do, post, options)
        commit(:do, JSON[post])
      end

      def dorecurring(amount, options = {})
        post = {}
        post[:total] = amount
        generate_post_data(:dorecurring, post, options)
        commit(:dorecurring, JSON[post])
      end

      def tokenquery(options = {})
        post = {}
        generate_post_data(:tokenquery, post, options)
        commit(:tokenquery, JSON[post])
      end

      def tokencancel(options = {})
        post = {}
        generate_post_data(:tokencancel, post, options)
        commit(:tokencancel, JSON[post])
      end

      def cardquery(options = {})
        post = {}
        generate_post_data(:cardquery, post, options)
        commit(:cardquery, JSON[post])
      end

      def cardcancel(options = {})
        post = {}
        generate_post_data(:cardcancel, post, options)
        commit(:cardcancel, JSON[post])
      end

      def self.utilbackref(url)
        uri    = URI.parse(url)
        params = CGI.parse(uri.query)
        return {
          :r => Base64.decode64(params['r'][0]),
          :s => params['s'][0]
        }
      end

      def self.utilIPN(json, signature)
        if json.is_a? String
          json = JSON[json]
        end

        if get_signature(:merchant_key, json) == signature
          json[:receiveDate] = generate_timeout(0)
          commit(:IPN, json)
          return true
        else
          return false
        end
      end

      private

      def generate_salt()
        chars = ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
        salt = (0...32).map { chars[rand(chars.length)] }.join
        return salt
      end

      def generate_timeout(timeout = @options[:timeout] || 10)
        now = Time.now + (timeout * 60)
        return now.strftime('%FT%T%:z')
      end

      def generate_order_ref()
        srand
        time = Time.now.to_s[0..18]
        formatted = time
            .gsub!('-', '')
            .gsub!(' ', '')
            .gsub!(':', '')
        return "AMSP" + formatted + (0 + rand(9999)).to_s

      end

      def add_credit_card_data(post, credit_card)
        post[:cardData] = {
          :number => credit_card.number,
          :expiry => expdate(credit_card),
          :cvc => credit_card.verification_value,
          :holder => credit_card.first_name + ' ' + credit_card.last_name
        }
      end

      def generate_post_data(action, post, options)
        case action
          when :start
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdk_version
            post[:methods] = ['CARD'] || options[:methods]
            post[:timeout] = generate_timeout
            post[:url] = @options[:redirect_url]
            options[:address] = options.delete :address1
            post[:invoice] = options[:address]
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:delivery)
              post[:delivery] = options[:delivery]
            end
            if options.key?(:three_ds_req_auth_method)
              post[:threeDSReqAuthMethod] = options[:three_ds_req_auth_method]
            end
            if options.key?(:recurring)
              post[:recurring] = {
                :times => options[:recurring][:times],
                :until => options[:recurring][:until],
                :maxAmount => options[:recurring][:max_amount]
              }
            end
            if options.key?(:only_card_reg)
              post[:onlyCardReg] = options[:only_card_reg]
              post[:twoStep] = true
            end
            if options.key?(:may_select_email)
              post[:maySelectEmail] = options[:may_select_email]
            end
            if options.key?(:may_select_invoice)
              post[:maySelectInvoice] = options[:may_select_invoice]
            end
            if options.key?(:may_select_delivery)
              post[:maySelectDelivery] = options[:may_select_delivery]
            end
            if options.key?(:card_secret)
              post[:cardSecret] = options[:card_secret]
            end

          when :authorize
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdk_version
            post[:methods] = ['CARD']
            post[:timeout] = generate_timeout
            post[:url] = @options[:redirect_url]
            post[:twoStep] = true
            options[:address] = options.delete :address1
            post[:invoice] = options[:address]
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:delivery)
              post[:delivery] = options[:delivery]
            end
            if options.key?(:three_ds_req_auth_method)
              post[:threeDSReqAuthMethod] = options[:three_ds_req_auth_method]
            end
            if options.key?(:recurring)
              post[:recurring] = {
                :times => options[:recurring][:times],
                :until => options[:recurring][:until],
                :maxAmount => options[:recurring][:max_amount]
              }
            end
            if options.key?(:only_card_reg)
              post[:onlyCardReg] = options[:only_card_reg]
              post[:twoStep] = true
            end
            if options.key?(:may_select_email)
              post[:maySelectEmail] = options[:may_select_email]
            end
            if options.key?(:may_select_invoice)
              post[:maySelectInvoice] = options[:may_select_invoice]
            end
            if options.key?(:may_select_delivery)
              post[:maySelectDelivery] = options[:may_select_delivery]
            end

          when :capture
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id]
            post[:originalTotal] = options[:original_total]
            post[:currency] = self.default_currency
            post[:sdkVersion] = self.sdk_version

          when :refund
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id]
            post[:currency] = self.default_currency
            post[:sdkVersion] = self.sdk_version
          
          when :query
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:transactionIds] = options[:transaction_ids] || []
            post[:orderRefs] = options[:order_ids] || []
            post[:sdkVersion] = self.sdk_version
            if options.key?(:detailed)
              post[:detailed] = options[:detailed]
            end
            if options.key?(:refunds)
              post[:refunds] = options[:refunds]
            end

          when :auto
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdk_version
            post[:methods] = ['CARD']
            post[:timeout] = generate_timeout
            post[:url] = @options[:redirect_url]
            post[:twoStep] = false
            post[:invoice] = options[:address]
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:three_ds)
              post[:threeDSReqAuthMethod] = options[:three_ds][:three_ds_req_auth_method]
              post[:threeDSReqAuthType]   = options[:three_ds][:three_ds_req_auth_type]
              if options[:three_ds].key?(:browser)
                post[:browser] = {
                  :accept  => options[:three_ds][:browser][:accept],
                  :agent  => options[:three_ds][:browser][:agent],
                  :ip => options[:three_ds][:browser][:ip],
                  :java  => options[:three_ds][:browser][:java],
                  :lang => options[:three_ds][:browser][:lang],
                  :color => options[:three_ds][:browser][:color],
                  :height => options[:three_ds][:browser][:height],
                  :width => options[:three_ds][:browser][:width],
                  :tz => options[:three_ds][:browser][:tz]
                }
              end
            end
            if options.key?(:three_ds_external)
              post[:threeDSExternal] = options[:three_ds_external]
            end
            if options.key?(:recurring)
              post[:recurring] = {
                :times => options[:recurring][:times],
                :until => options[:recurring][:until],
                :maxAmount => options[:recurring][:max_amount]
              }
            end

          when :do
            post[:salt] = generate_salt()
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdk_version
            post[:methods] = ['CARD']
            post[:total] = options[:amount]
            post[:cardId] = options[:card_id]
            post[:cardSecret] = options[:card_secret]
            post[:invoice] = options[:address]
            if options.key?(:items)
              post[:items] = options[:items]
            end
            if options.key?(:delivery)
              post[:delivery] = options[:delivery]
            end
            if options.key?(:three_ds)
              post[:threeDSReqAuthMethod] = options[:three_ds][:three_ds_req_auth_method]
              post[:type] = 'CIT'
              if options[:three_ds].key?(:browser)
                post[:browser] = {
                  :accept  => options[:three_ds][:browser][:accept],
                  :agent  => options[:three_ds][:browser][:agent],
                  :ip => options[:three_ds][:browser][:ip],
                  :java  => options[:three_ds][:browser][:java],
                  :lang => options[:three_ds][:browser][:lang],
                  :color => options[:three_ds][:browser][:color],
                  :height => options[:three_ds][:browser][:height],
                  :width => options[:three_ds][:browser][:width],
                  :tz => options[:three_ds][:browser][:tz]
                }
              end
            end
            if options.key?(:maySelectEmail)
              post[:maySelectEmail] = options[:may_select_email]
            end
            if options.key?(:maySelectInvoice)
              post[:maySelectInvoice] = options[:may_select_invoice]
            end
            if options.key?(:maySelectDelivery)
              post[:maySelectDelivery] = options[:may_select_delivery]
            end

          when :dorecurring
            post[:salt] = generate_salt()
            post[:token] = options[:token]
            post[:merchant] = @options[:merchant_id]
            post[:orderRef] = options[:order_id] || generate_order_ref()
            post[:currency] = self.default_currency
            post[:customerEmail] = options[:email]
            post[:language] = self.language
            post[:sdkVersion] = self.sdk_version
            post[:methods] = ['CARD']
            post[:timeout] = generate_timeout
            post[:type] = options[:type]
            post[:threeDSReqAuthMethod] = options[:three_ds_req_auth_method]
            post[:invoice] = options[:address]
            if options.key?(:items)
              post[:items] = options[:items]
            end

          when :tokenquery
            post[:token]      = options[:token],
            post[:merchant]   = @options[:merchant_id],
            post[:salt]       = generate_salt,
            post[:sdkVersion] = self.sdk_version

          when :tokencancel
            post[:token]      = options[:token]
            post[:merchant]   = @options[:merchant_id]
            post[:salt]       = generate_salt,
            post[:sdkVersion] = self.sdk_version
        
          when :cardquery
            post[:cardId]     = options[:card_id]
            post[:history]    = options[:history] || false
            post[:merchant]   = @options[:merchant_id]
            post[:salt]       = generate_salt
            post[:sdkVersion] = self.sdk_version

          when :cardcancel
            post[:cardId]      = options[:card_id]
            post[:merchant]   = @options[:merchant_id]
            post[:salt]       = generate_salt
            post[:sdkVersion] = self.sdk_version
        end
      end

      def parse_headers(key, message)
        signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::SHA384.new, key, message)).gsub("\n", '')
        {
          'Content-Type' => 'application/json',
          'Signature' => signature
        }
      end

      def get_signature(key, message)
        return Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::SHA384.new, key, message)).gsub("\n", '')
      end

      def commit(action, parameters)
        url = (test? ? test_url[action] : live_url[action])
        headers = parse_headers(@options[:merchant_key], parameters)
        response = JSON[ssl_post(url, parameters, headers)]

        puts action
        puts parameters
        puts response
        puts "\n"

        Response.new(
          success_from(response),
          message_from(response, parameters),
          response,
          authorization: authorization_from(response),
          avs_result: nil, #AVSResult.new(code: response['some_avs_response_key']),
          cvv_result: nil, #CVVResult.new(response['some_cvv_response_key']),
          test: test?,
          error_code: error_code_from(response)
        )
      end

      def success_from(response)
        !response.key?('errorCodes')
      end

      def message_from(response, parameters)
        if success_from(response)
          if test?
            return 'OK'
          end
          if @options[:return_request]
            return [parameters, response]
          end
          return response
        else
          if test?
            return 'FAIL'
          end
          errors = []
          if response["errorCodes"].length > 0
            response["errorCodes"].each do |error|
              errors << STANDARD_ERROR_CODE_MAPPING[error.to_s]
            end
            if @options[:return_request]
              return [parameters, errors]
            end
            return errors
          end
          return 'Unknown failure.'
        end
      end

      def authorization_from(response)
        if success_from(response)
          {
            :order_id => response['orderRef'],
            :amount => response['total']
          }
        else
          nil
        end
      end

      def error_code_from(response)
        unless success_from(response)
          response["errorCodes"]
        end
      end

    end
  end
end