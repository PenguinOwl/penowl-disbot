require 'discordrb'
require 'open-uri'
require 'pg'
require 'date'

$conn = 0
$error = 0
def todays
  Time.now.strftime("%Y=%m=%H")
end
def taxdays(mydate)
    mydate.month != mydate.next_day.next_day.next_day.next_day.next_day.month 
end
def link
  $conn = PG::Connection.open(ENV['DATABASE_URL'])
  yield
  unless $conn.finished? then 
    $conn.close 
  end
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
    $conn.exec_params("insert into users (userid, serverid, tax, bal, credit, taxamt, daily, invest, invcost, lbcount, state) values ($1, $2, 0, 700, 0, 5, 150, 0, 500, 0, 0)", [mem.distinct, mem.server.id])
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
  begin
    begin
      begin
        unless getVals(event.author, :state) == "1" and not command == "unfreeze"
          Command.send(command,event,*args)
        else
          event.respond "**Your account is frozen! Unfreeze it will** `#{$prefix}unfreeze`"
        end
      rescue ArgumentError
        mem = event.author
        if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)  && getVals(mem, :state) == "0"
          setStat(event.author, :tax, getVals(event.author, :tax).to_i+getVals(event.author, :taxamt).to_i)
        end
        event.respond("Argument error!")
      end
    rescue NoMethodError
      mem = event.author
      if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        setStat(event.author, :tax, getVals(event.author, :tax).to_i+getVals(event.author, :taxamt).to_i)
      end
      event.respond("That's not a command!")
    end
  rescue PG::UnableToSend
  end
end

$bot.message(start_with: $prefix) do |event|
  link do
    if event.message.content.strip[0] == $prefix
      puts "caught command"
      cmd = event.message.content.strip
      unless cmd[1] == ">"
        cmd.downcase!
      end
      cmd[0] = ""
      cmd = cmd.split(" ")
      top = cmd[0]
      cmd.map! {|e| e.gsub("_"," ")}
      cmd.delete_at(0)
      puts top
      command(top, event, cmd)
      mem = event.author
    end
    if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s) && getVals(mem, :state) == "0"
      tax(mem, event)
    end
  end
end

def tax(mem, event)
  mem = mem.on event.channel.server
  if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
    setStat(mem, :tax, getVals(event.author, :tax).to_i+getVals(mem, :taxamt).to_i)
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
    mem = event.author
    if event.message.mentions.size == 0
      if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        event.respond("You owe $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01} to the IRS. You have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.")
      else
        event.respond("You have paid your taxes.")
      end
    end
    event.message.mentions.each do |mem|
      if getVals(mem.on(event.channel.server), :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
        mem = mem.on(event.channel.server)
        event.respond(mem.mention + " owes $#{sprintf "%.2f", getVals(mem, :tax).to_f * 0.01} to the IRS. They have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.")
      else
        event.respond(mem.mention + " has paid their taxes.")
      end
    end
  end
  
  def Command.freeze(event, arg="elolo")
    if arg == "confirm"
      mem = event.author
      setStat(mem, :state, 1)
      event.respond("**Your account has been frozen.**")
    else
      event.respond("**" + event.author.mention + ", are you sure that you want to freeze your account? This action will reset your balance. If your are sure you want to proceed, do*** `#{$prefix}freeze confirm`")
    end
  end
  
  def Command.unfreeze(event)
    mem = event.author
    setStat(mem, :bal, 0)
    setStat(mem, :state, 0)
    event.respond("**Your account has been unfrozen and your balance has been reset.**")
  end
  
  def Command.money(event, *args)
    mem = event.author
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      event.respond("**You have $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.**")
    end
    event.message.mentions.each do |mem|
      mem = mem.on(event.channel.server)
      event.respond("**" + mem.mention + " has $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}.**")
    end
  end
  
  def Command.balance(event, *args)
    money(event, *args)
  end
  
  def Command.stats(event, *args)
    info(event, *args)
  end
  
  def Command.bal(event, *args)
    money(event, *args)
  end
  
  def Command.collect(event, *args)
    reward(event, *args)
  end
  
  def Command.info(event, *args)
    mem = event.author
    conc = ""
    if event.message.mentions.size == 0
      if args.size != 0
        tax mem, event
      end
      s = ""
      if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
         s = "$" + sprintf("%.2f", getVals(mem, :tax).to_f * 0.01)
      else
         s = "Paid"
      end
      mem = event.author
      n = ""
      if mem.nick
        n = mem.nick
      else
        n = mem.username
      end
      conc = "**" + n + "**'s Stats```Tax: #{s}\nBalance: $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}\nHourly Reward: $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01}\nTax Rate: $#{sprintf "%.2f", getVals(mem, :taxamt).to_f * 0.01} per message\nInvestments: #{getVals(mem, :invest).to_s}\nInvestment Cost: $#{sprintf "%.2f", getVals(mem, :invcost).to_f * 0.01}\nTimes Lobbied: #{getVals(mem, :lbcount)}```"
    end
    event.message.mentions.each do |mem|
      s = ""
      mem = mem.on(event.channel.server)
      if getVals(mem, :month) != (Date.today.year.to_s + "-" + Date.today.month.to_s)
         s = "$" + sprintf("%.2f", getVals(mem, :tax).to_f * 0.01)
      else
         s = "Paid"
      end
      n = ""
      if mem.nick
        n = mem.nick
      else
        n = mem.username
      end
      conc = "**" + n + "**'s Stats```Tax: #{s}\nBalance: $#{sprintf "%.2f", getVals(mem, :bal).to_f * 0.01}\nHourly Reward: $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01}\nTax Rate: $#{sprintf "%.2f", getVals(mem, :taxamt).to_f * 0.01} per message\nInvestments: #{getVals(mem, :invest).to_s}\nInvestment Cost: $#{sprintf "%.2f", getVals(mem, :invcost).to_f * 0.01}\nTimes Lobbied: #{getVals(mem, :lbcount)}```"
    end
    event.respond conc
  end
  
  def Command.reward(event)
    mem = event.author
    unless getVals(mem, :day) == todays
      setStat(mem, :bal, getVals(mem, :daily).to_i + getVals(mem, :bal).to_i)
      setStat(mem, :day, todays)
      event.respond "**Collected $#{sprintf "%.2f", getVals(mem, :daily).to_f * 0.01} from the bank.**"
    else
      event.respond "You already collected your reward!"
    end
  end
  
  def Command.lobby(event, type)
    mem = event.author
    unless getVals(mem, :lbday) == Date.today.to_s
      if ["taxes", "investments", "rates"].include? type
        setStat(mem, :lbday, Date.today.to_s)
        setStat(mem, :lbcount, getVals(mem, :lbcount).to_i + 1)
        chance = 4
        if Date.today.sunday? or Date.today.saturday?
          chance = 9
        end
        if rand(chance) == 1
          event.respond "***YOU WERE CAUGHT IN THE PROCESS OF LOBBYING. YOU WERE SUED BY THE STATE.***"
          setStat(mem, :tax, getVals(mem, :lbcount).to_i*getVals(mem, :invcost).to_i/2 + getVals(mem, :tax).to_i)
        else
          if type == "rates"
            event.respond "**You successfully lobbied the tax code!**"
            unless getVals(mem, :taxamt).to_i < 4
              setStat(mem, :taxamt, getVals(mem, :taxamt).to_i - rand(3))
            end
          elsif type == "investments"
            event.respond "**You successfully lobbied the stock market!**"
            setStat(mem, :invcost, getVals(mem, :invcost).to_i - (getVals(mem, :invcost).to_i / 3))
          elsif type == "taxes"
            event.respond "**You successfully lobbied your local tax collecter!**"
            setStat(mem, :tax, getVals(mem, :tax).to_i / 2) 
          end
        end
      else
        event.respond "You can only lobby three agencies: investments, taxes, and rates."
        tax mem,event
      end
    else
      event.respond "You have already lobbied today!"
    end
  end
  
  def Command.help(event)
    event.channel.send_embed do |em|
      em.title = "Commands"
      em.color = 313600
      af(em, "help", "not hard to guess")
      af(em, "taxes [users]", "displays tax information")
      af(em, "balance [users]", "displays balance - aliases: bal, money")
      af(em, "info [users]", "displays everything you need to know - alias: stats")
      af(em, "pay (user) (amount)", "give someone some of your money")
      af(em, "collect", "collect your hourly wages")
      af(em, "invest", "invest money (shown in #{$prefix}info) to increase your hourly payment")
      af(em, "lobby (investments|taxes|rates)", "lobby the government to decrease one of your debts")
      af(em, "paytaxes", "p a y   y o u r   t a x e s")
      em.footer = Discordrb::Webhooks::EmbedFooter.new(text: "the irs is always watching", icon_url: $bot.profile.avatar_url)
    end
  end
  
  def Command.pay(event, ment, amt)
    mem = event.author
    amt = amt.to_s.match(/[\d\.]+/)[0].to_f.*(100).to_i
    bal = getVals(mem, :bal).to_i
    if amt <= getVals(mem, :bal).to_i
      if event.message.mentions.size == 1
        mem2 = event.message.mentions[0].on(event.channel.server)
        setStat(mem, :bal, bal-amt)
        setStat(mem2, :bal, getVals(mem2, :bal).to_i + amt)
        event.respond "**Paid " + mem2.mention + " $#{sprintf "%.2f", amt.to_f * 0.01}.**"
      else
        event.respond "Mention someone to pay them!"
        tax mem,event
      end
    else
      event.respond "Not enough money!"
    end
  end
    
  def Command.invest(event)
    mem = event.author.on(event.channel.server)
    if getVals(mem, :invcost).to_i <= getVals(mem, :bal).to_i
      event.respond "*Invested $#{sprintf "%.2f", getVals(mem, :invcost).to_f * 0.01} into the stock market.*"
      setStat(mem, :bal, getVals(mem, :bal).to_i - getVals(mem, :invcost).to_i)
      diff = (rand(getVals(mem, :invcost).to_i/5) - getVals(mem, :invcost).to_i/20) * 2
      if diff > 0
        event.respond "**Success!** Your investments matured and you recived a $#{sprintf "%.2f", diff.to_f * 0.01} raise!"
      else
        event.respond "**Oh no!** Your investments failed and you took a $#{sprintf "%.2f", diff.to_f * -0.01} cut."
      end
      setStat(mem, :invcost, getVals(mem, :invcost).to_i + (getVals(mem, :invcost).to_i / 5) + diff)
      setStat(mem, :daily, getVals(mem, :daily).to_i + diff)
      setStat(mem, :invest, getVals(mem, :invest).to_i + 1)
      irs = rand(2)
      if irs == 1 and diff > 0 
        event.respond "*The IRS saw your investment and decided to raise your taxes.*"
        setStat(mem, :taxamt, getVals(mem, :taxamt).to_i + getVals(mem, :invcost).to_i / 500)
      else
        irs = 0
      end
    else
      event.respond "Not enough money!"
    end
  end
  
  def Command.paytaxes(event)
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

$bot.ready do
  $bot.game= "do "+$prefix+"help | " + (ENV['HEROKU_RELEASE_VERSION'] if ENV['DEV'] != "false")
end

$bot.run 
