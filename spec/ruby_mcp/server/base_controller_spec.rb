# frozen_string_literal: true

RSpec.describe RubyMCP::Server::BaseController do
  let(:env) { Rack::MockRequest.env_for('/test') }
  let(:request) { Rack::Request.new(env) }
  let(:params) { { id: '123' } }
  let(:controller) { described_class.new(request, params) }

  describe '#initialize' do
    it 'stores the request and params' do
      expect(controller.request).to eq(request)
      expect(controller.params).to eq(params)
    end
  end

  describe '#json_response' do
    it 'returns a rack response with JSON data' do
      status, headers, body = controller.send(:json_response, 200, { success: true })

      expect(status).to eq(200)
      expect(headers['Content-Type']).to eq('application/json')
      expect(JSON.parse(body.first)).to eq({ 'success' => true })
    end
  end

  describe '#ok' do
    it 'returns a 200 OK response with data' do
      status, _, body = controller.send(:ok, { result: 'success' })

      expect(status).to eq(200)
      expect(JSON.parse(body.first)).to eq({ 'result' => 'success' })
    end
  end

  describe '#created' do
    it 'returns a 201 Created response with data' do
      status, _, body = controller.send(:created, { id: '123' })

      expect(status).to eq(201)
      expect(JSON.parse(body.first)).to eq({ 'id' => '123' })
    end
  end

  describe '#bad_request' do
    it 'returns a 400 Bad Request response with error message' do
      status, _, body = controller.send(:bad_request, 'Invalid parameters')

      expect(status).to eq(400)
      expect(JSON.parse(body.first)).to eq({ 'error' => 'Invalid parameters' })
    end
  end

  describe '#not_found' do
    it 'returns a 404 Not Found response with error message' do
      status, _, body = controller.send(:not_found, 'Resource not found')

      expect(status).to eq(404)
      expect(JSON.parse(body.first)).to eq({ 'error' => 'Resource not found' })
    end
  end

  describe '#server_error' do
    it 'returns a 500 Internal Server Error response with error message' do
      status, _, body = controller.send(:server_error, 'Something went wrong')

      expect(status).to eq(500)
      expect(JSON.parse(body.first)).to eq({ 'error' => 'Something went wrong' })
    end
  end
end
