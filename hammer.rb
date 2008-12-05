#Method exposed to dialplan.rb that will treat the incoming calls
methods_for :dialplan do  
  def treat_call
    #First we collect the variables from the Asterisk channel with instructions on what to do with this call
    strategy_name = get_variable "strategy_name"

    #Now, lets treat the call
    sleep COMPONENTS.hammer[:common][:before_delay].to_i
    if send_dtmf != nil
      dtmf COMPONENTS.hammer[:treatment_strategies][strategy_name][:dtmf]
      sleep COMPONENTS.hammer[:treatment_strategies][strategy_name][:after_delay].to_i
    end
    if message != nil
      play COMPONENTS.hammer[:treatment_strategies][strategy_name][:message]
    end
    sleep COMPONENTS.hammer[:treatment_strategies][strategy_name][:call_length].to_i
  end
end

#Hammer class
class Hammer
  
  def initialize  
  end
  
  def start
    #Loop making the calls until someone kills us
    loop do
      make_calls
      sleep COMPONENTS.hammer[:common][:delay_between_cycles]
    end
  end
  
  private 
  
  #Method to initiate the call blocks and determine if they 
  #should be done in threads simultaneously or synchronously 
  def make_calls
    cnt = 0
    while cnt < COMPONENTS.hammer[:common][:cycle_length] do
      if COMPONENTS.hammer[:common][:thread_cycles] == true
        Thread.new do
          execute_strategies
        end
      else
        execute_strategies
      end
    cnt += 1
    end
  end
  
  #Method to execute a call for each of the treatment strategies set
  def execute_strategies
    COMPONENTS.hammer[:treatment_strategies].each do |treatment_strategy|

      strategy_name = nil
      treatment_strategy.each_key {|key| strategy_name = key}
      treatment_strategy.each_value {|value| treatment_strategy = value}

      result = launch_call(strategy_name, treatment_strategy)

      if COMPONENTS.hammer[:common][:delay_between_calls] == 'random'
        sleep rand(COMPONENTS.hammer[:common][:max_random_between_calls])
      else
        sleep COMPONENTS.hammer[:common][:delay_between_calls]
      end
    end
  end
  
  #Launch the individual phone calls
  def launch_call(strategy_name, treatment_strategy)
    channel = COMPONENTS.hammer[:dial_strategies][0][treatment_strategy[:dial]][:channel] + treatment_strategy[:number].to_s
    options = { "Channel" => channel,
                "Context" =>  COMPONENTS.hammer[:dial_strategies][0][treatment_strategy[:dial]][:context],
                "Exten" =>  COMPONENTS.hammer[:dial_strategies][0][treatment_strategy[:dial]][:extension],
                "Priority" => COMPONENTS.hammer[:dial_strategies][0][treatment_strategy[:dial]][:priority],
                "Callerid" => treatment_strategy[:callerid],
                "Timeout" => COMPONENTS.hammer[:dial_strategies][0][treatment_strategy[:dial]][:timeout],
                "Variable" => "strategy_name=" + strategy_name,
				        "Async" => COMPONENTS.hammer[:dial_strategies][0][treatment_strategy[:dial]][:async] }
    result = Adhearsion::VoIP::Asterisk.manager_interface.originate options
    ahn_log.hammer.debug result["Message"]
    return result
  end

end

begin
  #Now launch the hammer and let it run
  Thread.new do
    sleep COMPONENTS.hammer[:common][:initial_delay].to_i
    Hammer.new.start
  end
rescue => err
  ahn_log.hammer.error "Error when attempting to start the Hammer"
  ahn_log.hammer.error err
end