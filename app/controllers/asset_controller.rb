class AssetController < ApplicationController
  def index
    @assets = oa_list_unspent
  end

  def send_form
    @from_address = params["from_address"]
    @asset_id = params["asset_id"]
    @asset_amount = params["asset_amount"]
  end

  def sent
    send_asset(params["from_address"], params["asset_id"], params["asset_amount"].to_i, params["to_address"])
  end

  private

  require 'bitcoin'
  require 'net/http'
  require 'uri'
  require 'json'
  require 'ffi'
  require 'openassets'

  include Bitcoin::Util

  USER = "kindai"
  PW   = "nasubitomatoninjin"
  HOST = "localhost"
  PORT = 18332

  def bitcoind(method, param)
    http = Net::HTTP.new(HOST, PORT)
    r = Net::HTTP::Post.new('/')
    r.basic_auth(USER, PW)
    r.content_type = 'application/json'
    r.body = {method: method, params: param, id: 'jsonrpc'}.to_json
    JSON.parse(http.request(r).body)["result"]
  end

  ################################################
  # ブロックチェイン関連

  # ブロックチェインの情報を取得
  def getblockchaininfo
    bitcoind('getblockchaininfo', nil)
  end

  # ブロックカウントを取得
  def getblockcount
    bitcoind('getblockcount', nil)
  end

  # ブロックハッシュを取得
  def getblockhash(index)
    bitcoind('getblockhash', [index])
  end

  # ブロックヘッダを取得
  def getblockheader(hash)
    bitcoind('getblockheader', [hash])
  end

  ################################################
  # ワレット関連

  # アカウントに対するビットコイン保有量
  def getbalance(acc)
    bitcoind('getbalance', [acc])
  end

  # ビットコインアドレスに対するビットコイン保有量
  def getamount(addr)
    listaddressgroupings[0].select{|x|x[0] == addr}[0][1]
  end

  # ワレット内のUTXO一覧
  def listunspent
    bitcoind('listunspent', nil)
  end

  # アカウントに関するトランザクション一覧
  def listtransactions(acc)
    bitcoind('listtransactions', [acc])
  end

  # アカウントからビットコインアドレスへのビットコインの送金
  # トランザクションIDが返る
  def sendfrom(ac, to, amount)
    bitcoind('sendfrom', [ac, to, amount])
  end

  # アカウントからビットコインアドレスを得る
  def getaccountaddress(acc)
    bitcoind('getaccountaddress', [acc])
  end

  # ビットコインアドレスからアカウントを得る
  def getaccount(addr)
    bitcoind('getaccount', [addr])
  end

  # アカウントに対して新しいビットコインアドレスを生成する
  def new_addr(acc)
    bitcoind('getaccountaddress', [acc])
  end

  # トランザクションIDから確認数を得る
  def get_tx_confirmations(txid)
    tr = bitcoind('gettransaction', [txid])
    tr["confirmations"]
  end

  # ワレットのアカウントからビットコインアドレス一覧を得る
  def getaddressesbyaccount(acc)
    bitcoind('getaddressesbyaccount', [acc])
  end

  # bitcoindで保有するビットコインアドレスとその保有量一覧を得る
  def listaddressgroupings
    bitcoind('listaddressgroupings', nil)
  end

  ################################################
  # Open Assets Protocolのクライアント

  def openasset
    OpenAssets::Api.new({
      :network => 'testnet',
      :provider => 'bitcoind',
      :cache => 'testnet.db',
      :dust_limit => 600,
      :default_fees => 10000,
      :min_confirmation => 1,
      :max_confirmation => 9999999,
      :rpc => {user: USER, password: PW, schema: 'http', port: PORT, host: HOST}
    })
  end

  # 手数料(satoshi)
  FEE = 100000

  # 新規アセットの発行
  def issue_asset(oa_addr, amount, metadata, div)
    openasset.issue_asset(oa_addr, amount, metadata, nil, FEE, 'broadcast', div)
  end

  # アセットの転送
  def send_asset(from, asset_id, amount, to)
    openasset.send_asset(from, asset_id, amount, to, FEE, 'broadcast')
  end

  # アセットの焼却（アドレスが持っている指定アセットをすべて焼却）
  def burn_asset(oa_addr, asset_id)
    openasset.burn_asset(oa_addr, asset_id, FEE, 'broadcast')
  end

  # 未使用アセット一覧
  def oa_list_unspent
    openasset.list_unspent
  end

  # オープンアセットアドレスの収支を知る
  def oa_get_balance(oa_addr)
    openasset.get_balance(oa_addr)
  end

  # ビットコインの分割送金(多数のUTXOへの分割）
  def send_bitcoin(from, amount, to, qty)
    openasset.send_bitcoin(from, amount, to, FEE, 'broadcast', qty)
  end

  ################################################
  # そのほか

  # メッセージへの電子署名
  def signmessage(addr, msg)
    bitcoind('signmessage', [addr, msg])
  end

  # 電子署名の検証
  def verifymessage(addr, sig, msg)
    bitcoind('verifymessage', [addr, sig, msg])
  end

  # ビットコインアドレスをオープンアセットアドレスに変換
  # version = "00" minnet, "6F" testnet
  def to_oa_address(addr)
    if addr[0] == 'm' or addr[0] == 'n'
    then # testnet
      version = "6F"
    else # mainnet
      version = "00"
    end
    oa = '13' + version + ('0' + base58_to_int(addr).to_s(16)[0..-9])[-40..-1]
    encode_base58(oa + checksum(oa))
  end

  # JSON.pretty_generate()を使って表示
  def pretty(method)
    puts JSON.pretty_generate(method)
  end
end
