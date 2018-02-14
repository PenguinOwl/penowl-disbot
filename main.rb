require 'discordrb'
require 'open-uri'
require 'pg'
require 'date'

$error = 0
def taxdays(mydate)
    mydate.month != mydate.next_day.next_day.next_day.next_day.next_day.month 
end
def link
  $conn = PG::Connection.open(ENV['DATABASE_URL'])
  yield
  $conn.close
end
def getVals(mem, type)
  a = true
  type = type.to_s
  $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
    result.each do |row|
      return row.values_at(type).first
      a = false
    end
  end
  if a
    $conn.exec_params("insert into users (userid, serverid, tax, bal, credit, taxamt, daily, invest) values ($1, $2, 0, 500, 0, 5, 100, 0)", [mem.distinct, mem.server.id])
    $conn.exec_params("select * from users where userid=$1 and serverid=$2", [mem.distinct, mem.server.id]) do |result|
      result.each do |row|
        return row.values_at(type).first
        a = false
      end
    end
  end
end
def setStat(mem, type, val)
  type = type.to_s
  getVals(mem, :tax)
  $conn.exec_params("update users set #{type}=$1 where userid=$2 and serverid=$3", [val, mem.distinct, mem.server.id])
end
$prefix= '='
puts "key", ENV['KEY']
$bot = Discordrb::Bot.new token: ENV['KEY'], client_id: ENV['CLIENT']
puts $bot.invite_url
puts ARGV[0]
def command(command,event,args)
#  begin
#    begin
       Command.send(command,event,*args)
#    rescue ArgumentError
#      event.respond("Argument error!")
#    end
#  rescue NoMethodError
#    event.respond("That's not a command!")
#  end
end

=begin
fo = File.new('daboi.png', 'w+')
fo.write open(ENV['THEMAN']).read

puts open(ENV['THENMAN']).size
=end

$bot.message(start_with: $prefix) do |event|
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
      if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        setStat(event.author, :tax, getVals(event.author, :tax).to_i+getVals(event.author, :taxamt).to_i)
      end
    end
  end
end

def af(em, cmd, ds)
  em.add_field(name: $prefix+cmd, value: ds)
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
        if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
          mem = event.author
          event.respond("You owe $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01} to the IRS. You have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.")
        else
          event.respond("You have paid your taxes.")
        end
      end
      event.message.mentions.each do |mem|
        if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
          mem = mem.on(event.channel.server)
          event.respond(mem.mention + " owes $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01} to the IRS. They have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.")
        else
          event.respond("You have paid your taxes.")
        end
      end
    end
  end
  
  def Command.info(event, *args)
    link do
      mem = event.author
      conc = ""
      if event.message.mentions.size == 0
        s = ""
        if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
           s = sprintf "%.2f", getVals(mem, :tax).to_f * 0.01
        else
           s = "Paid"
        end
        mem = event.author
        conc = "**" + mem.nick + "**'s Stats```Tax: #{"$"+s}\nBalence: $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}\nDaily Reward: $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01}\nTax Rate: $#{sprintf "%.2f", getVals(mem, :taxamt).to_f * 0.01} per message\nInvestments: #{getVals(mem, :invest).to_s}```"
      end
      event.message.mentions.each do |mem|
        s = ""
        if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
           s = sprintf "%.2f", getVals(mem, :tax).to_f * 0.01
        else
           s = "Paid"
        end
        mem = mem.on(event.channel.server)
        conc = "**" + mem.nick + "**'s Stats```Tax: #{"$"+s}\nBalence: $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}\nDaily Reward: $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01}\nTax Rate: $#{sprintf "%.2f", getVals(mem, :taxamt).to_f * 0.01} per message\nInvestments: #{getVals(mem, :invest).to_s}```"
      end
      event.respond conc
    end
  end
  
  def Command.daily(event)
    mem = event.author
    link do
      unless getVals(mem, :day) == Date.today.to_s
        setStat(mem, :bal, getVals(mem, :daily).to_i + getVals(mem, :bal).to_i)
        setStat(mem, :day, Date.today.to_s)
        event.respond "Collected $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01} from the bank."
      else
        event.respond "You already collected your reward!"
      end
    end
  end
  
  def Command.help(event)
    event.channel.send_embed do |em|
      em.title = "Commands"
      af(em, "help", "not hard to guess")
      af(em, "taxes [users]", "displays tax information")
      af(em, "info [users]", "displays everything you need to know")
      af(em, "pay (user) (amount)", "give someone some of your money")
      af(em, "daily", "collect your daily wages")
      em.footer = Discordrb::Webhooks::EmbedFooter.new(text: "the irs is always watching", icon_url: $bot.profile.avatar_url)
    end
  end
  
  def Command.pay(event, ment, amt)
    link do
      mem = event.author
      amt = amt.to_s.match(/[\d\.]+/)[0].to_f.*(100).to_i
      bal = getVals(mem, :bal).to_i
      if amt <= getVals(mem, :bal).to_i
        if event.message.mentions.size == 1
          mem2 = event.message.mentions[0].on(event.channel.server)
          setStat(mem, :bal, bal-amt)
          setStat(mem2, :bal, getVals(mem2, :bal).to_i + amt)
          event.respond "Paid " + mem2.mention + " $#{sprintf "%.2f", amt.to_f * 0.01}."
        else
          event.respond "Mention someone to pay them!"
        end
      else
        event.respond "Not enough money!"
      end
    end
  end
  
  def Command.paytaxes(event)
    link do
      mem = event.author
      if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        if getVals(mem, :tax).to_i <= getVals(mem, :bal).to_i
          if taxdays(Date.today)
            setStat(mem, :bal, getVals(mem, :bal).to_i - getVals(mem, :tax).to_i)
            setStat(mem, :tax, 0)
            setStat(mem, :month, Date.today.year.to_s + "-" + Date.today.month.to_s)
            event.respond "Taxes paid for the month of " + Date.today.strftime("%B") + "."
          else
            event.respond "You may only pay your taxes on the last 5 days of the month!"
          end
        else
          event.respond "You do not have enough money to pay your taxes!"
        end
      else
        event.respond "You have already paid your taxes this month!"
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
