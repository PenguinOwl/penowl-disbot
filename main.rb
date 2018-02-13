require 'discordrb'
require 'open-uri'
require 'pg'

$error = 0
def link
  $conn = PG::Connection.open(ENV['DATABASE_URL'])
  yield
  $conn.close
end
def getVals(mem)
  a = true
  $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at('tax', 'bal')
      a = false
    end
  end
  if a
    $conn.exec_params("insert into users (userid, serverid, tax, bal, credit) values ($1, $2, 0, 0, 0)", [mem.distinct, mem.server.id])
    $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
      result.each do |row|
        return row.values_at('tax', 'bal')
        a = false
      end
    end
  end
end
def setStat(mem, tax, bal)
  st = getVals(mem)
  if tax == nil
    tax = st[0]
  end
  if bal == nil
    bal = st[1]
  end
  $conn.exec_params('update users set tax=$1, bal=$2 where userid=$3 and serverid=$4', [tax, bal, mem.distinct, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at('tax', 'bal')
    end
  end
end
prefix = '='
puts "key", ENV['KEY']
$bot = Discordrb::Bot.new token: ENV['KEY'], client_id: ENV['CLIENT']
puts $bot.invite_url
puts ARGV[0]
def command(command,event,args)
  begin
    begin
      Command.send(command,event,*args)
    rescue ArgumentError
      event.respond("Argument Error!!!1!!")
    end
  rescue NoMethodError
    event.respond("That's Not A Command!™")
  end
end

=begin
fo = File.new('daboi.png', 'w+')
fo.write open(ENV['THEMAN']).read

puts open(ENV['THENMAN']).size
=end

$bot.message(start_with: prefix) do |event|
  puts "caught command"
  cmd = event.message.content.downcase.strip
  cmd[0] = ""
  cmd = cmd.split(" ")
  top = cmd[0]
  cmd.map! {|e| e.gsub("_"," ")}
  cmd.delete_at(0)
  puts top
  command(top, event, cmd)
end

$bot.message(contains: /\W?.?c.?l.?u.?t.?\W?/i) do |event|
  event.respond "***GET THAT CANCA OUTTA HERE!!!***"
  event.message.delete
end

=begin
$bot.message() do |event|
  msga = event.message.content.split(" ")
  msga.map { |e| e.downcase }
  swra = ENV['BADWORDS'].split(', ')
  unless (msga & swra).empty?
    $bot.send_file(event.channel.id,fo)
  end
end
=end

$bot.message do |event|
  unless event.message.content[0] == "=" 
    link do
      st = getVals(event.author)
      setStat(event.author,st[0].to_i+1,nil)
    end
  end
end

class Command

  #-----------------------------
  #          COMMANDS
  #-----------------------------

  def Command.rubber(event)
    event.respond("woot")
  end
  
  def Command.version(event)
    event.respond(ENV['HEROKU_RELEASE_VERSION'])
  end

  def Command.ispaulgreat(event)
    event.respond("yea " + event.author.mention)
  end

  def Command.setplaying(event, text)
    if event.author.distinct=="PenguinOwl#3931"
      $bot.game= text
    else
      event.respond "but ur not penguin"
    end
  end

  def Command.taxes(event, *args)
    link do
      if event.message.mentions.size == 0
        mem = event.author
        st = getVals(mem)
        event.respond("You owe $#{sprintf "%.2f", st[0].to_f * 0.01} to the IRS. You have $#{sprintf "%.2f", st[1].to_f * 0.01}.")
      end
      event.message.mentions.each do |mem|
        mem = mem.on(event.channel.server)
        st = getVals(mem)
        event.respond(mem.mention + " owes $#{sprintf "%.2f", st[0].to_f * 0.01} to the IRS. They have $#{sprintf "%.2f", st[1].to_f * 0.01}.")
      end
    end
  end
  
  def Command.>(event, *args)
    if event.author.distinct=="PenguinOwl#3931"
      puts args.join " "
      event.respond eval args.join(" ")
    else
      event.respond "boi stop tryn to hack me"
    end
  end

  #-----------------------------
  #       END OF COMMANDS
  #-----------------------------

end
  
$bot.run 
