module Api::V2
  class ApiController < ApplicationController
    include Swagger::Docs::ImpotentMethods

    class << self
      Swagger::Docs::Generator::set_real_methods

      def inherited(subclass)
        super
        except_classes = [
          'Api::V2::ProfileController',
          'Api::V2::GenresController',
          'Api::V2::Shopping::CategoriesController',
        ]
        unless except_classes.include?(subclass.name)
          subclass.class_eval do
            setup_basic_api_documentation
          end
        end
      end

      def setup_authorization_header(api_action)
        swagger_api api_action do
          param :header, 'Authorization', :string, :required, 'Authentication token'
        end
      end

      private
      def setup_basic_api_documentation
        [:index, :show, :create, :update, :destroy].each do |api_action|
          setup_authorization_header(api_action)
        end
      end
    end
  end
end
