# frozen_string_literal: true

RSpec.describe MCP::Protocol::Types do
  describe '.text_content' do
    it 'creates a text content object' do
      content = described_class.text_content('Hello, world!')
      
      expect(content[:type]).to eq('text')
      expect(content[:text]).to eq('Hello, world!')
    end
  end
  
  describe '.image_content' do
    let(:image_data) { 'base64_encoded_data' }
    
    it 'creates an image content object' do
      content = described_class.image_content(image_data, 'image/png')
      
      expect(content[:type]).to eq('image')
      expect(content[:image][:data]).to eq(image_data)
      expect(content[:image][:mime_type]).to eq('image/png')
    end
    
    it 'uses PNG as the default mime type' do
      content = described_class.image_content(image_data)
      expect(content[:image][:mime_type]).to eq('image/png')
    end
  end
  
  describe '.resource_reference' do
    it 'creates a resource reference object' do
      reference = described_class.resource_reference('user.profile', { id: 123 })
      
      expect(reference[:type]).to eq('resource_reference')
      expect(reference[:resource][:name]).to eq('user.profile')
      expect(reference[:resource][:parameters]).to eq({ id: 123 })
    end
    
    it 'omits parameters if not provided' do
      reference = described_class.resource_reference('user.profile')
      
      expect(reference[:type]).to eq('resource_reference')
      expect(reference[:resource][:name]).to eq('user.profile')
      expect(reference[:resource][:parameters]).to be_nil
    end
  end
  
  describe '.tool_result' do
    it 'creates a tool result object' do
      result = { success: true, data: { value: 42 } }
      content = described_class.tool_result('calculator.add', result)
      
      expect(content[:type]).to eq('tool_result')
      expect(content[:tool_result][:tool_name]).to eq('calculator.add')
      expect(content[:tool_result][:result]).to eq(result)
    end
  end
  
  describe '.root_file_reference' do
    it 'creates a root file reference object' do
      reference = described_class.root_file_reference('project', '/src/main.rb')
      
      expect(reference[:type]).to eq('root_file_reference')
      expect(reference[:root_file][:root_name]).to eq('project')
      expect(reference[:root_file][:path]).to eq('/src/main.rb')
    end
  end
  
  describe '.text_delta' do
    it 'creates a text delta object' do
      delta = [
        { insert: 'Hello' },
        { retain: 5 },
        { delete: 3 }
      ]
      
      content = described_class.text_delta(delta)
      
      expect(content[:type]).to eq('text_delta')
      expect(content[:text_delta][:delta]).to eq(delta)
    end
  end
  
  describe '.is_text_content?' do
    it 'returns true for text content' do
      content = described_class.text_content('Hello')
      expect(described_class.is_text_content?(content)).to be(true)
    end
    
    it 'returns false for other content types' do
      image = described_class.image_content('data')
      expect(described_class.is_text_content?(image)).to be(false)
      
      reference = described_class.resource_reference('user.profile')
      expect(described_class.is_text_content?(reference)).to be(false)
    end
  end
  
  describe '.is_image_content?' do
    it 'returns true for image content' do
      content = described_class.image_content('data')
      expect(described_class.is_image_content?(content)).to be(true)
    end
    
    it 'returns false for other content types' do
      text = described_class.text_content('Hello')
      expect(described_class.is_image_content?(text)).to be(false)
    end
  end
  
  describe '.is_resource_reference?' do
    it 'returns true for resource references' do
      content = described_class.resource_reference('user.profile')
      expect(described_class.is_resource_reference?(content)).to be(true)
    end
    
    it 'returns false for other content types' do
      text = described_class.text_content('Hello')
      expect(described_class.is_resource_reference?(text)).to be(false)
    end
  end
  
  describe '.is_tool_result?' do
    it 'returns true for tool results' do
      content = described_class.tool_result('calculator.add', {})
      expect(described_class.is_tool_result?(content)).to be(true)
    end
    
    it 'returns false for other content types' do
      text = described_class.text_content('Hello')
      expect(described_class.is_tool_result?(text)).to be(false)
    end
  end
  
  describe '.is_root_file_reference?' do
    it 'returns true for root file references' do
      content = described_class.root_file_reference('project', '/file.txt')
      expect(described_class.is_root_file_reference?(content)).to be(true)
    end
    
    it 'returns false for other content types' do
      text = described_class.text_content('Hello')
      expect(described_class.is_root_file_reference?(text)).to be(false)
    end
  end
  
  describe '.is_text_delta?' do
    it 'returns true for text delta content' do
      content = described_class.text_delta([{ insert: 'Hello' }])
      expect(described_class.is_text_delta?(content)).to be(true)
    end
    
    it 'returns false for other content types' do
      text = described_class.text_content('Hello')
      expect(described_class.is_text_delta?(text)).to be(false)
    end
  end
  
  describe '.content_to_s' do
    it 'converts text content to string' do
      content = described_class.text_content('Hello, world!')
      expect(described_class.content_to_s(content)).to eq('Hello, world!')
    end
    
    it 'converts image content to [Image]' do
      content = described_class.image_content('data')
      expect(described_class.content_to_s(content)).to eq('[Image]')
    end
    
    it 'converts resource reference to [Resource: name]' do
      content = described_class.resource_reference('user.profile')
      expect(described_class.content_to_s(content)).to eq('[Resource: user.profile]')
    end
    
    it 'converts tool result to [Tool Result: name]' do
      content = described_class.tool_result('calculator.add', {})
      expect(described_class.content_to_s(content)).to eq('[Tool Result: calculator.add]')
    end
    
    it 'converts root file reference to [File: root/path]' do
      content = described_class.root_file_reference('project', '/file.txt')
      expect(described_class.content_to_s(content)).to eq('[File: project/file.txt]')
    end
    
    it 'converts text delta to [Text Delta]' do
      content = described_class.text_delta([{ insert: 'Hello' }])
      expect(described_class.content_to_s(content)).to eq('[Text Delta]')
    end
    
    it 'returns [Unknown Content] for unknown content types' do
      content = { type: 'unknown' }
      expect(described_class.content_to_s(content)).to eq('[Unknown Content]')
    end
  end
end