# frozen_string_literal: true

RSpec.describe "MCP::Server::Prompts::Manager" do
  let(:manager_class) { MCP::Server::Prompts::Manager }
  let(:prompt_class) { MCP::Server::Prompts::Prompt }
  let(:manager) { manager_class.new }
  let(:logger) { instance_double("Logger", debug: nil, error: nil) }
  
  before do
    # Mock logger
    allow(MCP).to receive(:logger).and_return(logger)
  end
  
  describe '#initialize' do
    it 'creates an empty prompts hash' do
      expect(manager.instance_variable_get(:@prompts)).to eq({})
    end
    
    it 'initializes with logger' do
      expect(manager.instance_variable_get(:@logger)).to eq(logger)
    end
  end
  
  describe '#register' do
    let(:prompt_name) { 'greeting' }
    let(:prompt) do
      prompt_class.new(
        prompt_name,
        ->(params) { "Hello, #{params[:name]}!" },
        parameters: { "type" => "object" }
      )
    end
    
    it 'registers a prompt' do
      manager.register(prompt)
      
      expect(manager.instance_variable_get(:@prompts)).to have_key(prompt_name)
      expect(manager.instance_variable_get(:@prompts)[prompt_name]).to eq(prompt)
    end
    
    it 'logs the registration' do
      expect(logger).to receive(:debug).with("Registered prompt: #{prompt_name}")
      manager.register(prompt)
    end
    
    it 'allows registering with a custom key' do
      custom_key = 'custom_key'
      manager.register(prompt, custom_key)
      
      expect(manager.instance_variable_get(:@prompts)).to have_key(custom_key)
      expect(manager.instance_variable_get(:@prompts)[custom_key]).to eq(prompt)
    end
    
    it 'raises an error if a prompt with the same key already exists' do
      manager.register(prompt)
      
      expect {
        manager.register(prompt)
      }.to raise_error(MCP::Errors::PromptError, "Prompt with key '#{prompt_name}' already exists")
    end
  end
  
  describe '#unregister' do
    let(:prompt_name) { 'greeting' }
    let(:prompt) do
      prompt_class.new(
        prompt_name,
        ->(params) { "Hello, #{params[:name]}!" }
      )
    end
    
    before do
      manager.instance_variable_get(:@prompts)[prompt_name] = prompt
    end
    
    it 'unregisters a prompt' do
      result = manager.unregister(prompt_name)
      
      expect(result).to eq(prompt)
      expect(manager.instance_variable_get(:@prompts)).not_to have_key(prompt_name)
    end
    
    it 'logs the unregistration' do
      expect(logger).to receive(:debug).with("Unregistered prompt: #{prompt_name}")
      manager.unregister(prompt_name)
    end
    
    it 'returns nil if the prompt does not exist' do
      result = manager.unregister('nonexistent')
      
      expect(result).to be_nil
      expect(logger).not_to have_received(:debug)
    end
  end
  
  describe '#get' do
    let(:prompt_name) { 'greeting' }
    let(:prompt) do
      prompt_class.new(
        prompt_name,
        ->(params) { "Hello, #{params[:name]}!" }
      )
    end
    
    before do
      manager.instance_variable_get(:@prompts)[prompt_name] = prompt
    end
    
    it 'returns the prompt with the given key' do
      result = manager.get(prompt_name)
      
      expect(result).to eq(prompt)
    end
    
    it 'returns nil if the prompt does not exist' do
      result = manager.get('nonexistent')
      
      expect(result).to be_nil
    end
  end
  
  describe '#exists?' do
    let(:prompt_name) { 'greeting' }
    
    before do
      manager.instance_variable_get(:@prompts)[prompt_name] = 'dummy_prompt'
    end
    
    it 'returns true if the prompt exists' do
      expect(manager.exists?(prompt_name)).to be(true)
    end
    
    it 'returns false if the prompt does not exist' do
      expect(manager.exists?('nonexistent')).to be(false)
    end
  end
  
  describe '#all' do
    let(:prompts) do
      {
        'greeting' => 'prompt1',
        'farewell' => 'prompt2'
      }
    end
    
    before do
      manager.instance_variable_set(:@prompts, prompts)
    end
    
    it 'returns all registered prompts' do
      result = manager.all
      
      expect(result).to eq(prompts)
    end
  end
  
  describe '#render' do
    let(:prompt_name) { 'greeting' }
    let(:prompt) do
      instance_double(
        prompt_class,
        render: [{ role: "assistant", content: "Hello, John!" }]
      )
    end
    
    before do
      manager.instance_variable_get(:@prompts)[prompt_name] = prompt
    end
    
    it 'renders the prompt with the given parameters' do
      params = { name: "John" }
      expect(prompt).to receive(:render).with(params)
      
      manager.render(prompt_name, params)
    end
    
    it 'returns the rendered prompt' do
      result = manager.render(prompt_name, { name: "John" })
      
      expect(result).to eq([{ role: "assistant", content: "Hello, John!" }])
    end
    
    it 'raises an error if the prompt does not exist' do
      expect {
        manager.render('nonexistent')
      }.to raise_error(MCP::Errors::PromptError, "Prompt not found: nonexistent")
    end
    
    it 'logs and raises an error if rendering fails' do
      error_message = "Something went wrong"
      allow(prompt).to receive(:render).and_raise(StandardError.new(error_message))
      
      expect(logger).to receive(:error).with("Error rendering prompt '#{prompt_name}': #{error_message}")
      
      expect {
        manager.render(prompt_name)
      }.to raise_error(MCP::Errors::PromptError, "Error rendering prompt '#{prompt_name}': #{error_message}")
    end
  end
  
  describe '#create_prompt' do
    let(:name) { 'greeting' }
    let(:description) { 'A greeting prompt' }
    let(:parameters) { { 'type' => 'object' } }
    let(:tags) { ['greeting'] }
    let(:block) { ->(params) { "Hello, #{params[:name]}!" } }
    
    it 'creates a new prompt with the given parameters' do
      expect(prompt_class).to receive(:new).with(
        name, block, parameters: parameters, description: description, tags: tags
      )
      
      manager.create_prompt(name, description: description, parameters: parameters, tags: tags, &block)
    end
    
    it 'returns the created prompt' do
      prompt = double('Prompt')
      allow(prompt_class).to receive(:new).and_return(prompt)
      
      result = manager.create_prompt(name, &block)
      
      expect(result).to eq(prompt)
    end
  end
  
  describe '#register_handlers' do
    let(:server) { double('Server') }
    
    it 'registers the prompts/list method handler' do
      expect(server).to receive(:on_method).with('prompts/list')
      expect(server).to receive(:on_method).with('prompts/get')
      
      manager.register_handlers(server)
    end
  end
  
  describe '#handle_list' do
    let(:prompt1) { instance_double(prompt_class, to_mcp_prompt: { name: 'prompt1' }) }
    let(:prompt2) { instance_double(prompt_class, to_mcp_prompt: { name: 'prompt2' }) }
    
    before do
      manager.instance_variable_set(:@prompts, {
        'prompt1' => prompt1,
        'prompt2' => prompt2
      })
    end
    
    it 'returns a hash with all prompts' do
      result = manager.send(:handle_list)
      
      expect(result).to be_a(Hash)
      expect(result[:prompts]).to be_an(Array)
      expect(result[:prompts]).to contain_exactly({ name: 'prompt1' }, { name: 'prompt2' })
    end
  end
  
  describe '#handle_get' do
    let(:prompt_name) { 'greeting' }
    let(:prompt) { instance_double(prompt_class) }
    let(:messages) { [{ role: "assistant", content: "Hello, John!" }] }
    
    before do
      allow(manager).to receive(:render).and_return(messages)
    end
    
    it 'renders the prompt with the given arguments' do
      params = { name: prompt_name, arguments: { name: "John" } }
      
      expect(manager).to receive(:render).with(prompt_name, { name: "John" })
      
      manager.send(:handle_get, params)
    end
    
    it 'returns a hash with the rendered messages' do
      params = { name: prompt_name, arguments: { name: "John" } }
      
      result = manager.send(:handle_get, params)
      
      expect(result).to be_a(Hash)
      expect(result[:messages]).to eq(messages)
    end
    
    it 're-raises prompt errors' do
      allow(manager).to receive(:render).and_raise(MCP::Errors::PromptError.new("Prompt not found"))
      
      expect {
        manager.send(:handle_get, { name: 'nonexistent' })
      }.to raise_error(MCP::Errors::PromptError, "Prompt not found")
    end
    
    it 'logs and wraps other errors' do
      error_message = "Something went wrong"
      allow(manager).to receive(:render).and_raise(StandardError.new(error_message))
      
      expect(logger).to receive(:error).with("Error getting prompt #{prompt_name}: #{error_message}")
      
      expect {
        manager.send(:handle_get, { name: prompt_name })
      }.to raise_error(MCP::Errors::PromptError, "Error getting prompt: #{error_message}")
    end
  end
end